function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a & b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a | b;
endfunction

function Bit#(1) xor1( Bit#(1) a, Bit#(1) b );
    return a ^ b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~ a;
endfunction

// Exercise 1 (4 Points): Using the and, or, and not gates, re-implement the function multiplexer1
// How many gates are needed? anser: 4 
function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    // return (sel == 0)? a : b;
    return or1(and1(not1(sel), a), and1(sel, b));
endfunction

// Exercise 2 (1 Point): Complete the implementation of the function multiplexer5 
// using for loops and multiplexer1.
// function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
//     // return (sel == 0)? a : b;
//     Bit#(5) result;
//     for (Integer i = 0; i < 5; i = i + 1)
//         result[i] = multiplexer1(sel, a[i], b[i]);
//     return result;
// endfunction


// Exercise 3 (2 Points): Complete the definition of the function multiplexer_n. 
typedef 5 N;
function Bit#(N) multiplexerN(Bit#(1) sel, Bit#(N) a, Bit#(N) b);
    // return (sel == 0)? a : b;
    Bit#(N) result;
    for (Integer i = 0; i < valueOf(N); i = i + 1)
        result[i] = multiplexer1(sel, a[i], b[i]);
    return result;
endfunction

function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    return multiplexerN(sel, a, b);
endfunction

//typedef 32 N; // Not needed
function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
    return (sel == 0)? a : b;
endfunction
