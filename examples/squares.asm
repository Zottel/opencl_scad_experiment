// Number of elements
mov $256 -> rob@in0

loop:
	// i = i - 1
	rob@out       -> pu0@in0
	mov $1        -> pu0@in1
	mov (subN, 4) -> pu0@opc
	pu0@out       -> rob@in0
	pu0@out       -> rob@in0
	
	// 2 copies of mem[i]
	(ld, 2) -> lsu@opc
	st      -> lsu@opc
	$0      -> lsu@in1 // load value
	pu0@out -> lsu@in0 // load addr
	
	// mem[i] * mem[i]
	lsu@out       -> pu0@in0
	lsu@out       -> pu0@in1
	mov (mulN, 1) -> pu0@opc
	// store addr
	pu0@out       -> lsu@in0
	// store value
	pu0@out       -> lsu@in1
	
	// loop condition
	// (i != 0) -> branch to loop
	loop    -> cu@in1
	rob@out -> cu@in0

// cleanup
rob@out -> null
