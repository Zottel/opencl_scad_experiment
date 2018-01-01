
// load input[0]
$0 -> lsu_input@in0 // addr
$0 -> lsu_input@in1 // value, ignored for load
(ld, 1) -> lsu_input@opc // store value

// load input[1]
$1 -> lsu_input@in0 // addr
$0 -> lsu_input@in1 // value, ignored for load
(ld, 1) -> lsu_input@opc // store value

// input -> scratchpad[0]
$0 -> lsu@in0 // addr
lsu_input@out -> lsu@in1 // value
st -> lsu@opc // store value

// 123 -> output[0]
$0 -> lsu_output@in0 // addr
$123 -> lsu_output@in1 // value
st -> lsu_output@opc // store value

// input -> output[1]
$1 -> lsu_output@in0 // addr
lsu_input@out -> lsu_output@in1 // value
st -> lsu_output@opc // store value

// load scratchpad[0]
$0 -> lsu@in0 // addr
$0 -> lsu@in1 // value, ignored for load
(ld, 1) -> lsu@opc // store value

// scratchpad -> output[2]
$3 -> lsu_output@in0 // addr
lsu@out -> lsu_output@in1 // value
st -> lsu_output@opc // store value


