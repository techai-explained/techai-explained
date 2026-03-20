---
title: "RAG Explained: Build Smarter AI With Your Own Data"
duration: "10 minutes"
voice: "en-US-GuyNeural"
---

## [TITLE] RAG Explained
Build Smarter AI With Your Own Data

## [BULLETS] What Is RAG?
- RAG = Retrieval-Augmented Generation
- A pattern that gives LLMs access to external knowledge at query time
- Three steps: **Retrieve** relevant context → **Augment** the prompt → **Generate** the answer
- Eliminates hallucinations by grounding responses in real data
- No model retraining required — your data stays fresh

## [COMPARISON] RAG vs Fine-Tuning
| Dimension | RAG | Fine-Tuning |
|-----------|-----|-------------|
| Data freshness | Always current | Frozen at training time |
| Cost | Low — no GPU training | High — requires GPU hours |
| Setup complexity | Moderate | High |
| Hallucination control | Strong — cites sources | Weak — baked into weights |
| Best for | Factual Q&A, search | Style, tone, format |
| Update cycle | Minutes | Days to weeks |

## [BULLETS] Vector Embeddings — The Core Idea
- Text is converted into high-dimensional numerical vectors
- Semantically similar text lands close together in vector space
- "How do I reset my password?" ≈ "I forgot my login credentials"
- Embedding models: OpenAI `text-embedding-3-small`, Cohere `embed-v3`, open-source `bge-large`
- Vectors are stored in a vector database for fast similarity search

## [CODE] Generating Embeddings
```python
from openai import OpenAI

client = OpenAI()

def get_embedding(text: str) -> list[float]:
    """Convert text into a vector embedding."""
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text
    )
    return response.data[0].embedding

# Example usage
doc_text = "Kubernetes uses a declarative API model"
vector = get_embedding(doc_text)
print(f"Dimensions: {len(vector)}")  # 1536
```

## [DIAGRAM] The Full RAG Pipeline
```
 ┌─────────────────────────────────────────────────────────┐
 │                    INDEXING PHASE                        │
 │                                                         │
 │  Documents ──▶ Chunking ──▶ Embedding ──▶ Vector DB     │
 │  (PDF, MD,     (split      (text→vector)   (Pinecone,   │
 │   HTML...)      into                        Chroma,      │
 │                 pieces)                     Weaviate)    │
 └─────────────────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────┐
 │                    QUERY PHASE                          │
 │                                                         │
 │  User Query ──▶ Embed Query ──▶ Similarity Search       │
 │                                      │                  │
 │                                      ▼                  │
 │                               Top-K Chunks              │
 │                                      │                  │
 │                                      ▼                  │
 │                          Augmented Prompt ──▶ LLM ──▶   │
 │                          (query + context)     Answer    │
 └─────────────────────────────────────────────────────────┘
```

## [CODE] Complete RAG Pipeline in Python
```python
from langchain_community.document_loaders import DirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_chroma import Chroma
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough

# 1. Load documents
loader = DirectoryLoader("./docs", glob="**/*.md")
documents = loader.load()

# 2. Chunk documents
splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=50
)
chunks = splitter.split_documents(documents)

# 3. Create vector store
embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
vectorstore = Chroma.from_documents(chunks, embeddings)
retriever = vectorstore.as_retriever(search_kwargs={"k": 4})

# 4. Build the RAG chain
template = """Answer based only on this context:
{context}

Question: {question}"""
prompt = ChatPromptTemplate.from_template(template)
llm = ChatOpenAI(model="gpt-4o")

chain = (
    {"context": retriever, "question": RunnablePassthrough()}
    | prompt
    | llm
)

# 5. Query
answer = chain.invoke("How does authentication work?")
print(answer.content)
```

## [COMPARISON] Chunking Strategies
| Strategy | How It Works | Best For |
|----------|-------------|----------|
| Fixed-size | Split every N characters | Simple docs, logs |
| Recursive | Split by paragraphs → sentences → words | General purpose — the default choice |
| Semantic | Group by meaning using embeddings | Research papers, mixed-topic docs |
| Parent-child | Small chunks for search, return parent context | Long documents needing full context |

## [BULLETS] Chunking — The Details Matter
- Chunk size sweet spot: 256–512 tokens for most use cases
- Too small → lost context, too large → diluted relevance
- Overlap (50–100 tokens) prevents cutting sentences mid-thought
- Metadata matters: attach source, page number, section title to every chunk
- Experiment and measure — there is no universal "best" setting

## [BULLETS] Production RAG: Beyond the Basics
- **Hybrid search**: combine vector similarity + keyword search (BM25) for better recall
- **Re-ranking**: use a cross-encoder to re-score top results after initial retrieval
- **Query transformation**: rewrite user queries for better retrieval (HyDE, multi-query)
- **Contextual compression**: strip irrelevant parts from retrieved chunks before prompting
- **Guardrails**: filter results below a similarity threshold to avoid hallucinations

## [DIAGRAM] Hybrid Search Architecture
```
                    User Query
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
       Vector Search         BM25 Keyword
       (semantic)            (exact match)
              │                   │
              └─────────┬─────────┘
                        ▼
              Reciprocal Rank Fusion
                        │
                        ▼
                Cross-Encoder Re-Ranker
                        │
                        ▼
                   Top-K Results ──▶ LLM
```

## [BULLETS] Evaluating Your RAG System
- You cannot improve what you do not measure
- **Retrieval quality**: are the right chunks being returned? (Precision@K, Recall@K)
- **Answer quality**: is the final answer correct and grounded? (faithfulness, relevance)
- Tools: RAGAS, DeepEval, LangSmith, custom eval sets
- Build a golden test set of 50–100 question/answer pairs from real user queries
- Run evals on every pipeline change — treat RAG like any other software system

## [BULLETS] Key Takeaways
- RAG lets you ground LLMs in your own data without retraining
- The pipeline: chunk → embed → store → retrieve → augment → generate
- Chunking strategy and retrieval quality matter more than the LLM model choice
- Production systems need hybrid search, re-ranking, and evaluation
- Start simple, measure everything, iterate
