
import re
import os
import time
import json
import tempfile
import warnings
import streamlit as st
from groq import Groq
from langchain_chroma import Chroma
from langchain_community.document_loaders import PyPDFLoader
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from streamlit_autorefresh import st_autorefresh

# Suppress environment and library warnings
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN_WARNING"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"
warnings.filterwarnings("ignore")

st.set_page_config(page_title="Interactive Learning & Exam Portal", page_icon="🎓", layout="wide")

# -----------------------------------------------------------------------------
# 1. Initialize Groq Client
# -----------------------------------------------------------------------------
GROQ_API_KEY = "PASTE_YOUR_GROQ_API KEY HERE"
groq_client = Groq(api_key=GROQ_API_KEY)

MODEL_NAME = "openai/gpt-oss-120b"

def generate_answer(prompt, max_retries=3):
    """Call Groq API with rate-limit retry logic."""
    for attempt in range(max_retries):
        try:
            response = groq_client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=MODEL_NAME,
            )
            if response and response.choices:
                return response.choices[0].message.content
        except Exception as e:
            if "429" in str(e) or "rate_limit" in str(e).lower():
                wait_time = (2 ** attempt) * 2
                st.warning(f"⏳ Rate limit buffer active. Retrying in {wait_time}s...")
                time.sleep(wait_time)
            else:
                st.error(f"API Error: {str(e)}")
                return None
    st.error("❌ Request limit hit. Please wait a few seconds.")
    return None

def extract_json_array(text):
    """Safely extracts and parses a JSON array from raw model response using regex."""
    if not text:
        return []
    
    cleaned = text.replace("```json", "").replace("```", "").strip()
    match = re.search(r'\[.*\]', cleaned, re.DOTALL)
    if match:
        cleaned = match.group(0)
        
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        st.error("⚠️ Failed to parse response structure. Please re-generate.")
        return []

# -----------------------------------------------------------------------------
# 2. Embeddings & Database Setup
# -----------------------------------------------------------------------------
@st.cache_resource
def load_default_resources():
    embedding_function = HuggingFaceEmbeddings(
        model_name="sentence-transformers/all-MiniLM-L6-v2",
        model_kwargs={'device': 'cpu'}
    )
    default_vector_db = None
    if os.path.exists("./chroma_db_nccn"):
        default_vector_db = Chroma(
            persist_directory="./chroma_db_nccn", 
            embedding_function=embedding_function
        )
    return embedding_function, default_vector_db

embedding_function, default_vector_db = load_default_resources()

def process_uploaded_pdf(uploaded_file):
    """Processes newly uploaded PDF into Chroma Vector DB."""
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
        tmp_file.write(uploaded_file.read())
        tmp_path = tmp_file.name

    loader = PyPDFLoader(tmp_path)
    docs = loader.load()
    os.remove(tmp_path)

    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=100)
    split_docs = text_splitter.split_documents(docs)

    return Chroma.from_documents(documents=split_docs, embedding=embedding_function)

# -----------------------------------------------------------------------------
# 3. Exam & Quiz Helper Functions
# -----------------------------------------------------------------------------
def get_document_context(vector_db, num_chunks=5):
    if vector_db is None:
        return ""
    search_results = vector_db.similarity_search("main concepts core topics key details summary", k=num_chunks)
    return "\n".join([res.page_content for res in search_results])

def generate_mcq_quiz(vector_db):
    context = get_document_context(vector_db, num_chunks=5)
    prompt = f"""
You are an automated exam generator. Based on the document context below, generate EXACTLY 15 multiple-choice questions (MCQs).
Respond STRICTLY with a raw valid JSON array of objects. Do not include markdown brackets, conversational intro, or outro text.

JSON Structure per object:
[
  {{
    "id": 1,
    "question": "Question text here",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "answer": "Exact matching option string",
    "explanation": "Short explanation of why this option is correct."
  }}
]

CONTEXT:
{context}
"""
    raw_response = generate_answer(prompt)
    return extract_json_array(raw_response)

def generate_written_exam(vector_db, num_questions=5):
    context = get_document_context(vector_db, num_chunks=5)
    prompt = f"""
You are an automated exam generator. Based on the document context below, generate {num_questions} conceptual short-answer questions.
Respond STRICTLY with a raw valid JSON array of objects. Do not include markdown brackets, conversational intro, or outro text.

JSON Structure per object:
[
  {{
    "id": 1,
    "question": "Question text here",
    "max_marks": 5,
    "ideal_answer": "Key points that should be in the user's answer."
  }}
]

CONTEXT:
{context}
"""
    raw_response = generate_answer(prompt)
    return extract_json_array(raw_response)

def grade_written_exam(questions, user_answers):
    grading_prompt = f"""
You are a strict academic examiner. Grade the student's written answers based on the questions and reference criteria.

Questions & Student Answers:
"""
    for q in questions:
        q_id = q["id"]
        ans = user_answers.get(q_id, "No answer provided.")
        grading_prompt += f"""
Question {q_id}: {q['question']} (Max Marks: {q['max_marks']})
Reference Answer: {q['ideal_answer']}
Student Answer: {ans}
---
"""

    grading_prompt += """
Provide a structured evaluation formatted cleanly in Markdown:
1. Score breakdown for each question (e.g., Marks Obtained / Max Marks).
2. Feedback explaining what was answered correctly and what critical points were missed.
3. Total Score and Final Percentage.
"""
    return generate_answer(grading_prompt)

# -----------------------------------------------------------------------------
# 4. Sidebar Setup & Navigation
# -----------------------------------------------------------------------------
if "active_vector_db" not in st.session_state:
    st.session_state.active_vector_db = default_vector_db
if "current_file" not in st.session_state:
    st.session_state.current_file = "Default Database (chroma_db_nccn)" if default_vector_db else "None"

with st.sidebar:
    st.header("⚙️ Data Source")
    uploaded_file = st.file_uploader("Upload PDF (Optional)", type=["pdf"])
    
    if uploaded_file is not None:
        if st.session_state.current_file != uploaded_file.name:
            with st.spinner(f"Indexing `{uploaded_file.name}`..."):
                st.session_state.active_vector_db = process_uploaded_pdf(uploaded_file)
                st.session_state.current_file = uploaded_file.name
                st.session_state.mcq_data = None
                st.session_state.exam_questions = None
                st.session_state.simple_questions = None
                st.success(f"Successfully Indexed: `{uploaded_file.name}`")

    st.divider()
    mode = st.radio("Choose Mode", [
        "💬 AI Chat", 
        "📝 15 MCQ Quiz", 
        "✍️ Simple Written Exam", 
        "⏱️ Timed Written Exam"
    ])

# -----------------------------------------------------------------------------
# Mode 1: Document Q&A Assistant (RAG Chat)
# -----------------------------------------------------------------------------
if mode == "💬 AI Chat":
    st.title("💬 Document Q&A Assistant")
    st.caption(f"Querying Document: **{st.session_state.current_file}**")

    if "messages" not in st.session_state:
        st.session_state.messages = []

    # Display existing chat history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Chat input box
    if user_query := st.chat_input("Ask a question about the document..."):
        if not st.session_state.active_vector_db:
            st.error("⚠️ No vector database found. Please upload a PDF file first.")
        else:
            st.session_state.messages.append({"role": "user", "content": user_query})
            with st.chat_message("user"):
                st.markdown(user_query)

            with st.chat_message("assistant"):
                with st.spinner("Searching document..."):
                    search_results = st.session_state.active_vector_db.similarity_search(user_query, k=4)
                    context = "\n".join([res.page_content for res in search_results])
                    prompt = f"Answer question STRICTLY based on the context provided:\n\nQUESTION: {user_query}\nCONTEXT: {context}"
                    answer = generate_answer(prompt)
                    if answer:
                        st.markdown(answer)
                        with st.expander("View Retrieved Context"):
                            st.text(context)
                        st.session_state.messages.append({"role": "assistant", "content": answer})

# -----------------------------------------------------------------------------
# Mode 2: 15 MCQ Quiz Mode
# -----------------------------------------------------------------------------
elif mode == "📝 15 MCQ Quiz":
    st.title("📝 15 Question MCQ Practice Quiz")
    st.caption(f"Generated from: **{st.session_state.current_file}**")

    if st.button("🔄 Generate New 15 MCQ Quiz") or "mcq_data" not in st.session_state or st.session_state.mcq_data is None:
        if not st.session_state.active_vector_db:
            st.error("⚠️ Please upload a PDF first to generate a quiz.")
        else:
            with st.spinner("Analyzing document and creating 15 MCQs..."):
                st.session_state.mcq_data = generate_mcq_quiz(st.session_state.active_vector_db)
                st.session_state.mcq_submitted = False
                st.session_state.user_mcq_answers = {}

    if st.session_state.get("mcq_data"):
        with st.form("mcq_form"):
            user_answers = {}
            for idx, item in enumerate(st.session_state.mcq_data):
                st.markdown(f"**Q{idx+1}: {item['question']}**")
                user_answers[item["id"]] = st.radio(
                    f"Select answer for Q{idx+1}:",
                    options=item["options"],
                    key=f"mcq_{item['id']}",
                    index=None
                )
                st.divider()

            submit_mcq = st.form_submit_button("Submit Quiz")

        if submit_mcq:
            st.session_state.mcq_submitted = True
            st.session_state.user_mcq_answers = user_answers

        if st.session_state.get("mcq_submitted", False):
            score = 0
            st.subheader("📊 Quiz Results")
            for item in st.session_state.mcq_data:
                q_id = item["id"]
                selected = st.session_state.user_mcq_answers.get(q_id)
                correct = item["answer"]
                
                if selected == correct:
                    score += 1
                    st.success(f"**Q{q_id}: Correct!** ({selected})")
                else:
                    st.error(f"**Q{q_id}: Incorrect.** Your choice: `{selected}` | Correct: `{correct}`")
                st.info(f"💡 *Explanation:* {item['explanation']}")
            
            total_qs = len(st.session_state.mcq_data)
            st.metric("Final Score", f"{score} / {total_qs}", f"{(score/total_qs)*100:.1f}%")

# -----------------------------------------------------------------------------
# Mode 3: Simple Written Exam Mode
# -----------------------------------------------------------------------------
elif mode == "✍️ Simple Written Exam":
    st.title("✍️ Self-Paced Written Exam")
    st.caption(f"Document: **{st.session_state.current_file}**")

    num_questions = st.slider("Number of Questions:", min_value=1, max_value=10, value=3, key="simple_num_q")

    if st.button("🚀 Start Simple Exam"):
        if not st.session_state.active_vector_db:
            st.error("⚠️ Please upload a PDF first to start an exam.")
        else:
            with st.spinner("Generating exam questions..."):
                st.session_state.simple_questions = generate_written_exam(
                    st.session_state.active_vector_db, 
                    num_questions=num_questions
                )
                st.session_state.simple_submitted = False
                st.session_state.simple_results = None
                st.rerun()

    if st.session_state.get("simple_questions") and not st.session_state.get("simple_submitted", False):
        with st.form("simple_exam_form"):
            user_simple_answers = {}
            for q in st.session_state.simple_questions:
                q_id = q["id"]
                st.markdown(f"**Q{q_id}: {q['question']}** ({q['max_marks']} Marks)")
                user_simple_answers[q_id] = st.text_area(
                    f"Your answer for Q{q_id}:",
                    key=f"simple_ans_{q_id}",
                    height=120
                )
                st.divider()

            submit_simple = st.form_submit_button("Submit Exam Now", type="primary", use_container_width=True)

        if submit_simple:
            st.session_state.simple_submitted = True
            st.session_state.user_simple_answers = user_simple_answers
            st.rerun()

    if st.session_state.get("simple_submitted", False) and not st.session_state.get("simple_results"):
        with st.status("🧠 AI Examiner is grading your responses...", expanded=True) as status:
            st.write("📥 Collecting submitted answers...")
            grading = grade_written_exam(
                st.session_state.simple_questions, 
                st.session_state.user_simple_answers
            )
            st.session_state.simple_results = grading
            status.update(label="✅ Evaluation Complete!", state="complete", expanded=False)
        st.rerun()

    if st.session_state.get("simple_submitted", False) and st.session_state.get("simple_results"):
        st.subheader("📋 Exam Evaluation & Marks Breakdown")
        st.markdown(st.session_state.simple_results)

# -----------------------------------------------------------------------------
# Mode 4: Timed Written Exam Mode
# -----------------------------------------------------------------------------
elif mode == "⏱️ Timed Written Exam":
    st.title("⏱️ Timed Written Exam System")
    st.caption(f"Document: **{st.session_state.current_file}**")

    if "exam_submitted" not in st.session_state:
        st.session_state.exam_submitted = False
    if "exam_results" not in st.session_state:
        st.session_state.exam_results = None

    if not st.session_state.get("exam_questions"):
        col1, col2 = st.columns(2)
        with col1:
            exam_duration_mins = st.slider("Select Duration (Minutes):", min_value=1, max_value=30, value=3, key="timed_dur")
        with col2:
            num_questions = st.slider("Number of Questions:", min_value=1, max_value=10, value=3, key="timed_num_q")

        if st.button("🚀 Start Timed Exam"):
            if not st.session_state.active_vector_db:
                st.error("⚠️ Please upload a PDF first to start an exam.")
            else:
                with st.spinner("Generating exam questions..."):
                    st.session_state.exam_questions = generate_written_exam(
                        st.session_state.active_vector_db, 
                        num_questions=num_questions
                    )
                    st.session_state.exam_start_time = time.time()
                    st.session_state.exam_duration_secs = exam_duration_mins * 60
                    st.session_state.exam_submitted = False
                    st.session_state.exam_results = None
                    st.rerun()

    if st.session_state.get("exam_questions") and not st.session_state.exam_submitted:
        elapsed = time.time() - st.session_state.exam_start_time
        remaining = int(st.session_state.exam_duration_secs - elapsed)

        timer_box = st.empty()

        if remaining > 0:
            st_autorefresh(interval=1000, key="exam_timer_refresher")
            mins, secs = divmod(remaining, 60)
            timer_box.warning(f"⏳ **Time Remaining:** `{mins:02d}:{secs:02d}`")
        else:
            timer_box.error("⏰ **Time is UP! Auto-submitting your exam now...**")
            st.session_state.exam_submitted = True
            st.rerun()

        with st.form("timed_exam_form"):
            for q in st.session_state.exam_questions:
                q_id = q["id"]
                st.markdown(f"**Q{q_id}: {q['question']}** ({q['max_marks']} Marks)")
                st.text_area(
                    f"Your answer for Q{q_id}:",
                    key=f"written_ans_{q_id}",
                    height=120
                )
                st.divider()

            submit_btn = st.form_submit_button("Submit Exam Now", type="primary", use_container_width=True)
            if submit_btn:
                st.session_state.exam_submitted = True
                st.rerun()

    if st.session_state.exam_submitted:
        if not st.session_state.exam_results:
            collected_answers = {}
            for q in st.session_state.get("exam_questions", []):
                q_id = q["id"]
                ans_key = f"written_ans_{q_id}"
                collected_answers[q_id] = st.session_state.get(ans_key, "No answer provided.")

            with st.status("🧠 AI Examiner is grading your responses...", expanded=True) as status:
                st.write("📥 Collecting submitted answers...")
                st.write("🔍 Evaluating with LLM...")
                
                grading = grade_written_exam(st.session_state.exam_questions, collected_answers)
                st.session_state.exam_results = grading
                status.update(label="✅ Evaluation Complete!", state="complete", expanded=False)

        if st.session_state.exam_results:
            st.subheader("📋 Exam Evaluation & Marks Breakdown")
            st.markdown(st.session_state.exam_results)
            
            st.divider()
            if st.button("🔄 Take Another Exam"):
                st.session_state.exam_questions = None
                st.session_state.exam_submitted = False
                st.session_state.exam_results = None
                st.rerun()# import time
