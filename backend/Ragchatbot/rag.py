import os

# Set environment variables BEFORE importing any libraries
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN_WARNING"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import signal
import sys

from google import genai
from google.genai import types
from langchain_chroma import Chroma
from langchain_huggingface import HuggingFaceEmbeddings

# Setup Gemini API Client
GEMINI_API_KEY = "PASTE_YOUR_API_KEY"
client = genai.Client(api_key=GEMINI_API_KEY)

# Handle Ctrl+C cleanly
def signal_handler(sig, frame):
    print('\nThanks for using Gemini! Bye! :)')
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

# Load Embeddings & ChromaDB ONCE at startup
print("Loading vector database and embedding model...")
embedding_function = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
vector_db = Chroma(persist_directory="./chroma_db_nccn", embedding_function=embedding_function)
print("Ready!\n")

def generate_rag_prompt(query, context):
    escaped = context.replace("'", "").replace('"', "").replace("\n", " ")
    prompt = f"""
You are a helpful and informative bot that answers questions using text from the reference context included below. \
Be sure to respond in a complete sentence, being comprehensive, including all relevant background information. \
However, you are talking to a non-technical audience, so be sure to break down complicated concepts and \
strike a friendly and conversational tone. \
If the context is irrelevant to the answer, you may ignore it.

QUESTION: '{query}'
CONTEXT: '{escaped}'

ANSWER:
"""
    return prompt

def get_relevant_context_from_db(query):
    search_results = vector_db.similarity_search(query, k=6)
    context = ""
    for result in search_results:
        context += result.page_content + "\n"
    return context

def generate_answer(prompt):
    # Standard generate_content call
    response = client.models.generate_content(
        model='gemini-3.5-flash',
        contents=prompt,
    )
    return response.text

welcome_text = generate_answer("Can you quickly introduce yourself in one short friendly sentence?")
print(welcome_text)

while True:
    print("-" * 70)
    print("What would you like to ask?")
    query = input("Query: ")
    
    if query.strip().lower() in ["exit", "quit"]:
        print("Goodbye!")
        break
        
    context = get_relevant_context_from_db(query)
    prompt = generate_rag_prompt(query=query, context=context)
    answer = generate_answer(prompt=prompt)
    print("\n" + answer + "\n")