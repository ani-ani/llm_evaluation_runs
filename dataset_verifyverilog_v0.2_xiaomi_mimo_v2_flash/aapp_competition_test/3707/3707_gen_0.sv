module oven_decision (
    input [15:0] n,
    input [15:0] t,
    input [15:0] k,
    input [15:0] d,
    output build_second
);

    // Internal signals
    wire [31:0] n_ext;
    wire [31:0] k_ext;
    wire [31:0] t_ext;
    wire [31:0] d_ext;
    
    // Extend inputs to 32 bits to prevent overflow during calculation
    assign n_ext = {16'b0, n};
    assign k_ext = {16'b0, k};
    assign t_ext = {16'b0, t};
    assign d_ext = {16'b0, d};

    // Calculate batches = ceil(n / k) = (n + k - 1) / k
    wire [31:0] batches;
    assign batches = (n_ext + k_ext - 1) / k_ext;

    // Calculate single_time = batches * t
    wire [31:0] single_time;
    assign single_time = batches * t_ext;

    // Condition: single_time > d + t
    // Use logic comparison
    assign build_second = (single_time > (d_ext + t_ext));

endmodule
