#import "Hash_Table";
#import "Basic";


// operator == :: (l: Some_StructA, r: Some_StructA) -> bool {
//     return l.val == r.val;
// }

// operator == :: (l: Some_StructB, r: Some_StructB) -> bool {
//     return l.some == r.some;
// }

Some_StructA :: struct {
    val: u32;
}

Some_StructB :: struct {
    some: Some_StructA;
}

operator == :: (l: Some_StructB, r: Some_StructB) -> bool {
    return l.some.val == r.some.val;
}

Ctx :: struct {
    map : Table(Some_StructB, int);
}

main :: (){
    first := Some_StructB.{
        some = .{val = 1}
    };
    second := Some_StructB.{
        some = .{val = 1}
    };
    assert(first == second);
    print("Hello\n");
}
