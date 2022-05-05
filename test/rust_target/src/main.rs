use std::io::Write;
use std::fs;


fn main(){
    let mut du = [0.; 3];
    let u0 = [1., 0., 0.];
    let p = [1.; 3];
    let t = 0.;
    println!("{:?} {:?} {:?} {:?}", du, u0, p, t);
    rust_target::diffeqf(&mut du, &u0, &p, &t);
    println!("{:?} {:?} {:?} {:?}", du, u0, p, t);
    let mut file = fs::File::create("foo.txt").expect("");
    let res = format!("{:?} {:?} {:?} {:?}", du, u0, p, t);
    file.write_all(&res.as_bytes()).expect("");
    ()
    // Ok(())
}
