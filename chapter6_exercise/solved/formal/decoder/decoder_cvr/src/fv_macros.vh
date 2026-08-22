// ============================================================
// fv_macros.vh — OSS Yosys/SymbiYosys icin yardimci makrolar
// ============================================================
// OSS Yosys temporal SVA desteklemiyor. $stable/$rose/$fell
// surume gore calisabilir ama garanti degil -> elle taniml.
// ============================================================

`ifndef FV_MACROS_VH
`define FV_MACROS_VH

// Tek cevrim gecmis operatorleri
`define FV_STABLE(x)   ($past(x) == (x))
`define FV_CHANGED(x)  ($past(x) != (x))
`define FV_ROSE(x)     (!$past(x) &&  (x))
`define FV_FELL(x)     ( $past(x) && !(x))

// $onehot0 karsiligi (OSS'de $onehot0 olmayabilir)
// Kullanim: `FV_ONEHOT0_5(a,b,c,d,e)
`define FV_ONEHOT0_2(a,b)           (((a)+(b)) <= 1)
`define FV_ONEHOT0_3(a,b,c)         (((a)+(b)+(c)) <= 1)
`define FV_ONEHOT0_4(a,b,c,d)       (((a)+(b)+(c)+(d)) <= 1)
`define FV_ONEHOT0_5(a,b,c,d,e)     (((a)+(b)+(c)+(d)+(e)) <= 1)
`define FV_ONEHOT0_6(a,b,c,d,e,f)   (((a)+(b)+(c)+(d)+(e)+(f)) <= 1)

`endif
