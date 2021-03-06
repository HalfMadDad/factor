USING: tools.test kernel sequences words sequences.private fry
prettyprint alien alien.accessors math.private
compiler.tree.builder compiler.tree.optimizer
compiler.cfg.builder compiler.cfg.debugger
compiler.cfg.optimizer compiler.cfg.rpo
compiler.cfg.predecessors compiler.cfg.checker compiler.cfg
arrays locals byte-arrays kernel.private math slots.private
vectors sbufs strings math.partial-dispatch hashtables assocs
combinators.short-circuit strings.private accessors
compiler.cfg.instructions compiler.cfg.representations ;
FROM: alien.c-types => int ;
IN: compiler.cfg.builder.tests

! Just ensure that various CFGs build correctly.
: unit-test-builder ( quot -- )
    '[ _ test-builder [ [ optimize-cfg check-cfg ] with-cfg ] each ] [ ] swap unit-test ;

: blahblah ( nodes -- ? )
    { fixnum } declare [
        dup 3 bitand 1 = [ drop t ] [
            dup 3 bitand 2 = [
                blahblah
            ] [ drop f ] if
        ] if
    ] any? ; inline recursive

: more? ( x -- ? ) ;

: test-case-1 ( -- ? ) f ;

: test-case-2 ( -- )
    test-case-1 [ test-case-2 ] [ ] if ; inline recursive

{
    [ ]
    [ dup ]
    [ swap ]
    [ [ ] dip ]
    [ fixnum+ ]
    [ fixnum+fast ]
    [ 3 fixnum+fast ]
    [ fixnum*fast ]
    [ 3 fixnum*fast ]
    [ 3 swap fixnum*fast ]
    [ fixnum-shift-fast ]
    [ 10 fixnum-shift-fast ]
    [ -10 fixnum-shift-fast ]
    [ 0 fixnum-shift-fast ]
    [ 10 swap fixnum-shift-fast ]
    [ -10 swap fixnum-shift-fast ]
    [ 0 swap fixnum-shift-fast ]
    [ fixnum-bitnot ]
    [ eq? ]
    [ "hi" eq? ]
    [ fixnum< ]
    [ 5 fixnum< ]
    [ float+ ]
    [ 3.0 float+ ]
    [ float<= ]
    [ fixnum>bignum ]
    [ bignum>fixnum ]
    [ fixnum>float ]
    [ float>fixnum ]
    [ 3 f <array> ]
    [ [ 1 ] [ 2 ] if ]
    [ fixnum< [ 1 ] [ 2 ] if ]
    [ float+ [ 2.0 float* ] [ 3.0 float* ] bi float/f ]
    [ { [ 1 ] [ 2 ] [ 3 ] } dispatch ]
    [ [ t ] loop ]
    [ [ dup ] loop ]
    [ [ 2 ] [ 3 throw ] if 4 ]
    [ int f "malloc" { int } alien-invoke ]
    [ int { int } cdecl alien-indirect ]
    [ int { int } cdecl [ ] alien-callback ]
    [ swap - + * ]
    [ swap slot ]
    [ blahblah ]
    [ 1000 [ dup [ reverse ] when ] times ]
    [ 1array ]
    [ 1 2 ? ]
    [ { array } declare [ ] map ]
    [ { array } declare dup 1 slot [ 1 slot ] when ]
    [ [ dup more? ] [ dup ] produce ]
    [ vector new over test-case-1 [ test-case-2 ] [ ] if ]
    [ [ [ nth-unsafe ".." = 0 ] dip set-nth-unsafe ] 2curry (each-integer) ]
    [
        { fixnum sbuf } declare 2dup 3 slot fixnum> [
            over 3 fixnum* over dup [ 2 slot resize-string ] dip 2 set-slot
        ] [ ] if
    ]
    [ [ 2 fixnum* ] when 3 ]
    [ [ 2 fixnum+ ] when 3 ]
    [ [ 2 fixnum- ] when 3 ]
    [ 10000 [ ] times ]
    [
        over integer? [
            over dup 16 <-integer-fixnum
            [ 0 >=-integer-fixnum ] [ drop f ] if [
                nip dup
                [ ] [ ] if
            ] [ 2drop f ] if
        ] [ 2drop f ] if
    ]
    [
        pick 10 fixnum>= [ [ 123 fixnum-bitand ] 2dip ] [ ] if
        set-string-nth-fast
    ]
} [
    unit-test-builder
] each

: test-1 ( -- ) test-1 ;
: test-2 ( -- ) 3 . test-2 ;
: test-3 ( a -- b ) dup [ test-3 ] when ;

{
    test-1
    test-2
    test-3
} [ unit-test-builder ] each

{
    byte-array
    alien
    POSTPONE: f
} [| class |
    {
        alien-signed-1
        alien-signed-2
        alien-signed-4
        alien-unsigned-1
        alien-unsigned-2
        alien-unsigned-4
        alien-cell
        alien-float
        alien-double
    } [| word |
        { class } word '[ _ declare 10 _ execute ] unit-test-builder
        { class fixnum } word '[ _ declare _ execute ] unit-test-builder
    ] each
    
    {
        set-alien-signed-1
        set-alien-signed-2
        set-alien-signed-4
        set-alien-unsigned-1
        set-alien-unsigned-2
        set-alien-unsigned-4
    } [| word |
        { fixnum class } word '[ _ declare 10 _ execute ] unit-test-builder
        { fixnum class fixnum } word '[ _ declare _ execute ] unit-test-builder
    ] each
    
    { float class } \ set-alien-float '[ _ declare 10 _ execute ] unit-test-builder
    { float class fixnum } \ set-alien-float '[ _ declare _ execute ] unit-test-builder
    
    { float class } \ set-alien-double '[ _ declare 10 _ execute ] unit-test-builder
    { float class fixnum } \ set-alien-double '[ _ declare _ execute ] unit-test-builder
    
    { pinned-c-ptr class } \ set-alien-cell '[ _ declare 10 _ execute ] unit-test-builder
    { pinned-c-ptr class fixnum } \ set-alien-cell '[ _ declare _ execute ] unit-test-builder
] each

[ t ] [ [ swap ] [ ##replace? ] contains-insn? ] unit-test

[ f ] [ [ swap swap ] [ ##replace? ] contains-insn? ] unit-test

[ t ] [
    [ { fixnum byte-array fixnum } declare set-alien-unsigned-1 ]
    [ [ ##store-memory? ] [ ##store-memory-imm? ] bi or ] contains-insn?
] unit-test

[ t ] [
    [ { fixnum byte-array fixnum } declare [ dup * dup * ] 2dip set-alien-unsigned-1 ]
    [ [ ##store-memory? ] [ ##store-memory-imm? ] bi or ] contains-insn?
] unit-test

[ f ] [
    [ { byte-array fixnum } declare set-alien-unsigned-1 ]
    [ [ ##store-memory? ] [ ##store-memory-imm? ] bi or ] contains-insn?
] unit-test

[ t t ] [
    [ { byte-array fixnum } declare alien-cell ]
    [ [ [ ##load-memory? ] [ ##load-memory-imm? ] bi or ] contains-insn? ]
    [ [ ##box-alien? ] contains-insn? ]
    bi
] unit-test

[ f ] [
    [ { byte-array integer } declare alien-cell ]
    [ [ ##load-memory? ] [ ##load-memory-imm? ] bi or ] contains-insn?
] unit-test

[ f ] [
    [ 1000 [ ] times ]
    [ [ ##peek? ] [ ##replace? ] bi or ] contains-insn?
] unit-test

[ f t ] [
    [ { fixnum alien } declare <displaced-alien> 0 alien-cell ]
    [ [ ##unbox-any-c-ptr? ] contains-insn? ]
    [ [ ##unbox-alien? ] contains-insn? ] bi
] unit-test

\ alien-float "intrinsic" word-prop [
    [ f t ] [
        [ { byte-array fixnum } declare alien-cell 4 alien-float ]
        [ [ ##box-alien? ] contains-insn? ]
        [ [ ##allot? ] contains-insn? ] bi
    ] unit-test

    [ f t ] [
        [ { byte-array fixnum } declare alien-cell { alien } declare 4 alien-float ]
        [ [ ##box-alien? ] contains-insn? ]
        [ [ ##allot? ] contains-insn? ] bi
    ] unit-test
    
    [ 1 ] [ [ dup float+ ] [ ##load-memory-imm? ] count-insns ] unit-test
] when

! Regression. Make sure everything is inlined correctly
[ f ] [ M\ hashtable set-at [ { [ ##call? ] [ word>> \ set-slot eq? ] } 1&& ] contains-insn? ] unit-test

! Regression. Make sure branch splitting works.
[ 2 ] [ [ 1 2 ? ] [ ##return? ] count-insns ] unit-test
