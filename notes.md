# Notes

## Chat with claude 

Most relevant LSP methods for LLM context gathering:
High value:

textDocument/definition - Get source definitions
textDocument/references - Find all usages
textDocument/documentSymbol - Get symbol structure
callHierarchy/incomingCalls - Understand callers
callHierarchy/outgoingCalls - See what functions are called
textDocument/hover - Get type info and docs
workspace/symbol - Find symbols across workspace

Medium value:

textDocument/implementation - Find concrete implementations
typeHierarchy/subtypes, supertypes - Understand type relationships
textDocument/semanticTokens/full - Get semantic meaning of code

Lower priority:

textDocument/declaration - Find original declarations
textDocument/diagnostic - Get error/warning context

The rest are mostly UI/formatting focused and less relevant for code understanding.
Let me know if you'd like a demo function implementing any of these methods. 
