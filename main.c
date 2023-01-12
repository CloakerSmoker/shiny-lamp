/* Include the generated header file */
#include "parser.h"
#include <stdio.h>

void print_tree(pgs_tree* tree, const char* source, int indent) {
    size_t i;
    /* Print an indent. */
    for(i = 0; i < indent; i++) printf("  ");
    /* If the tree is a terminal (actual token) */
    if(tree->variant == PGS_TREE_TERMINAL) {
        printf("%s: %.*s\n", pgs_terminal_name(PGS_TREE_T(*tree)), (int) (PGS_TREE_T_TO(*tree) - PGS_TREE_T_FROM(*tree)),
                source + PGS_TREE_T_FROM(*tree));
    } else {
        /* PGS_TREE_NT gives the nonterminal ID from the given tree. */
        printf("%s:\n", pgs_nonterminal_name(PGS_TREE_NT(*tree)));
        /* PGS_TREE_NT_COUNT returns the number of children a nonterminal
           node has. */
        for(i = 0; i < PGS_TREE_NT_COUNT(*tree); i++) {
            /* PGS_TREE_NT_CHILD gets the nth child of a nonterminal tree. */
            print_tree(PGS_TREE_NT_CHILD(*tree, i), source, indent + 1);
        }
    }
}

void doit(const char* string) {
    pgs_state _state; /* The state is used for reporting error messages.*/
    pgs_state* state = &_state;
    pgs_tree* tree; /* The tree that will be initialized */
    pgs_error error;
    pgs_token_list tokens;
    pgs_state_init(state);

    if((error = pgs_do_lex(state, &tokens, string))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
        else {
            printf("Error: %s\n", state->errbuff);
        }

        return;
    }

    printf("got %i tokens\n", tokens.token_count);

    for (int i = 0; i < tokens.token_count; i++) {
        pgs_token* t = pgs_token_list_at(&tokens, i);

        printf("(%s %.*s) ", pgs_terminal_name(t->terminal), t->to - t->from, string + t->from);
    }

    printf("\n");

    if((error = pgs_do_parse(state, &tokens, &tree))) {
        if(error == PGS_MALLOC) {
            pgs_state_error(state, error, "Failure to allocate memory while lexing");
        }
        else {
            printf("Error: %s\n", state->errbuff);
        }

        return;
    }

    print_tree(tree, string, 0);
}

int main(int argc, char** argv) {
    pgs_state state; /* The state is used for reporting error messages.*/
    pgs_tree* tree; /* The tree that will be initialized */
    char buffer[256]; /* Buffer for string input */

    gets(buffer); /* Unsafe function for the sake of example */
    /* pgs_do_all lexes and parses the text from the buffer. */

    doit(buffer);
}