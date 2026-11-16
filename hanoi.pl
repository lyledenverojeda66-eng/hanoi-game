:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_cors)).

% ---------- LOGIC ----------
hanoi(0, _, _, _, []) :- !.
hanoi(N, From, To, Via, Moves) :-
    N > 0, N1 is N - 1,
    hanoi(N1, From, Via, To, M1),
    hanoi(N1, Via, To, From, M2),
    append(M1, [move(From, To)|M2], Moves).

% Next recommended move from any position.
% Pegs = [Peg0, Peg1, Peg2], with each peg represented as a disk list.
next_move(K, Target, Pegs, Move) :-
    K > 0,
    where(K, Pegs, Pos),
    K1 is K - 1,
    (   Pos =:= Target
    ->  next_move(K1, Target, Pegs, Move)
    ;   Other is 3 - Pos - Target,
        (   next_move(K1, Other, Pegs, M) -> Move = M
        ;   Move = Pos-Target
        )
    ).

where(K, Pegs, Pos) :- nth0(Pos, Pegs, Peg), memberchk(K, Peg), !.

% ---------- BACKEND ----------
:- http_handler(root(hanoi), handle_hanoi, []).
:- http_handler(root(hint),  handle_hint,  []).

server(Port) :- http_server(http_dispatch, [port(Port)]).

handle_hanoi(Request) :-
    cors_enable,
    http_parameters(Request, [n(N, [integer, between(1, 9)])]),
    hanoi(N, left, right, center, Moves),
    length(Moves, Count),
    findall(_{from: F, to: T}, member(move(F, T), Moves), List),
    reply_json_dict(_{disks: N, total_moves: Count, moves: List}).

% GET /hint?n=4&pegs=4,3|2|1
handle_hint(Request) :-
    cors_enable,
    http_parameters(Request, [n(N, [integer, between(1, 9)]), pegs(S, [])]),
    split_string(S, "|", "", Parts),
    maplist(parse_peg, Parts, Pegs),
    (   next_move(N, 2, Pegs, From-To)
    ->  reply_json_dict(_{from: From, to: To})
    ;   reply_json_dict(_{done: true})
    ).

parse_peg("", []) :- !.
parse_peg(Str, L) :-
    split_string(Str, ",", "", Ps),
    maplist(number_string, L, Ps).

:- initialization(server(8080)).