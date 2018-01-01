//   Copyright 2018 Julius Roob <julius@juliusroob.de>
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

setup:
	
	$0 -> lsu@in0 // addr
	$0 -> lsu@in1 // value, ignored
	(ld, 1) -> lsu@opc // value, ignored
	
	// input -> 2x n
	lsu@out -> pu0@in0
	$0        -> pu0@in1
	(orB, 2)  -> pu0@opc
	
	// Immediate value instead of memory input
	//$32 -> pu0@in0
	//$32 -> pu0@in1
	//(orB, 2) -> pu0@opc
	
	// $0 -> 3x i
	$0 -> pu1@in0
	$0 -> pu1@in1
	(orB, 3) -> pu1@opc
	
	// $0 -> 3x fib(0)
	$1 -> pu2@in0
	$1 -> pu2@in1
	(orB, 3) -> pu2@opc
	
	$0 -> rob@in0

loop:
	// pu0: n, n
	// pu1: i, i
	// pu2: fib(i), fib(i)
	// rob: fib(i - 1)
	
	// fib(i) -> output[i]
	pu1@out -> lsu@in0 // addr: i
	pu2@out -> lsu@in1 // value: fib(i)
	st      -> lsu@opc
	
	// i = i + 1
	$1 -> pu1@in0 // 1
	pu1@out -> pu1@in1 // i
	(addN, 3) -> pu1@opc // i + 1
	
	// n == i implemented as (n - i)
	pu0@out -> pu0@in0 // n
	pu1@out -> pu0@in1 // i
	(subN, 1) -> pu0@opc // branch condition: (n - i)
	
	$0 -> pu0@in0 // 0
	pu0@out -> pu0@in1 // n
	(orB, 2) -> pu0@opc // n for next iteration
	
	rob@out -> pu2@in0 // fib(i - 1)
	pu2@out -> pu2@in1 // fib(i)
	(addN, 3) -> pu2@opc // fib(i + 1) = fib(i) + fib(i - 1)
	
	pu2@out -> rob@in0 // fib(i) -> fib(i - 1)
	
	
	// Loop condition/branch
	loop -> cu@in1
	pu0@out -> cu@in0

cleanup:
	pu0@out -> null
	pu0@out -> null
	pu0@out -> null
	pu1@out -> null
	pu1@out -> null
	pu1@out -> null
	pu2@out -> null
	pu2@out -> null
	rob@out -> null
