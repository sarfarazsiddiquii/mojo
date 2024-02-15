# ===----------------------------------------------------------------------=== #
#
# This file is Modular Inc proprietary.
#
# ===----------------------------------------------------------------------=== #
# RUN: %mojo -debug-level full %s | FileCheck %s

from memory.anypointer import AnyPointer
from testing.testing import _MoveCounter

from testing import *


struct MoveOnlyType(Movable):
    var value: Int

    fn __init__(inout self, value: Int):
        self.value = value

    fn __moveinit__(inout self, owned existing: Self):
        self.value = existing.value
        print("moved", self.value)

    fn __del__(owned self):
        print("deleted", self.value)


fn test_anypointer_of_move_only_type():
    # CHECK-LABEL: === test_anypointer
    print("=== test_anypointer")

    let ptr = AnyPointer[MoveOnlyType].alloc(1)
    # CHECK: moved 42
    ptr.emplace_value(MoveOnlyType(42))
    # CHECK: moved 42
    let value = ptr.take_value()
    # NOTE: Destructor is called before `print`.
    # CHECK: deleted 42
    # CHECK: value 42
    print("value", value.value)
    ptr.free()


def test_anypointer_move_into_move_count():
    let ptr = AnyPointer[_MoveCounter[Int]].alloc(1)

    let value = _MoveCounter(5)
    assert_equal(0, value.move_count)
    ptr.emplace_value(value ^)

    # -----
    # Test that `AnyPointer.move_into` performs exactly one move.
    # -----

    assert_equal(1, __get_address_as_lvalue(ptr.value).move_count)

    let ptr_2 = AnyPointer[_MoveCounter[Int]].alloc(1)

    ptr.move_into(ptr_2)

    assert_equal(2, __get_address_as_lvalue(ptr_2.value).move_count)


def test_refitem():
    let ptr = AnyPointer[Int].alloc(1)
    ptr[0] = 0
    ptr[] += 1
    assert_equal(ptr[], 1)
    ptr.free()


def test_refitem_offset():
    let ptr = AnyPointer[Int].alloc(5)
    for i in range(5):
        ptr[i] = i
    for i in range(5):
        assert_equal(ptr[i], i)
    ptr.free()


def test_address_of():
    let local = 1
    assert_not_equal(0, AnyPointer[Int].address_of(local).__as_index())


def test_bitcast():
    let local = 1
    let ptr = AnyPointer[Int].address_of(local)
    let aliased_ptr = ptr.bitcast[SIMD[DType.uint8, 4]]()

    assert_equal(ptr.__as_index(), ptr.bitcast[Int]().__as_index())

    assert_equal(ptr.__as_index(), aliased_ptr.__as_index())


def test_anypointer_string():
    let nullptr = AnyPointer[Int]()
    assert_equal(str(nullptr), "0x0")

    let ptr = AnyPointer[Int].alloc(1)
    assert_true(str(ptr).startswith("0x"))
    assert_not_equal(str(ptr), "0x0")
    ptr.free()


def test_eq():
    let local = 1
    let p1 = AnyPointer[Int].address_of(local)
    let p2 = p1
    assert_equal(p1, p2)

    let other_local = 2
    let p3 = AnyPointer[Int].address_of(other_local)
    assert_not_equal(p1, p3)
    let p4 = AnyPointer[Int].address_of(local)
    assert_not_equal(p1, p4)


def test_comparisons():
    let p1 = AnyPointer[Int].alloc(1)

    assert_true((p1 - 1) < p1)
    assert_true((p1 - 1) <= p1)
    assert_true(p1 <= p1)
    assert_true((p1 + 1) > p1)
    assert_true((p1 + 1) >= p1)
    assert_true(p1 >= p1)

    p1.free()


def main():
    test_address_of()

    test_refitem()
    test_refitem_offset()

    test_anypointer_of_move_only_type()
    test_anypointer_move_into_move_count()

    test_bitcast()
    test_anypointer_string()
    test_eq()
    test_comparisons()
