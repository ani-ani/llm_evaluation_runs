module costume_parity_solver(
    input  [2:0] n,
    input  [2:0] l_array [0:7],
    input  [2:0] r_array [0:7],
    input  [7:0] x_array,
    output [31:0] result
);

    // Local parameters
    localparam MOD = 32'd1000000007;

    // Internal signals
    integer assign_mask;
    integer i, j;
    reg [31:0] count;

    // Helper function to compute (idx modulo n) in [0, n-1]
    function automatic [2:0] wrap_idx;
        input integer idx;
        input [2:0] n_val;
        integer t;
        begin
            if (n_val == 0) begin
                wrap_idx = 3'd0;
            end else begin
                t = idx % n_val;
                if (t < 0) t = t + n_val;
                wrap_idx = t[2:0];
            end
        end
    endfunction

    // Function to compute parity over a circular segment [start..end] with wrap, inclusive.
    // Uses assign_mask bits as costume assignment.
    function automatic segment_parity;
        input integer center_i;
        input [2:0] l_i;
        input [2:0] r_i;
        input [2:0] n_val;
        input integer mask;
        integer offset;
        integer idx;
        reg parity;
        begin
            parity = 1'b0;
            // Iterate from -l_i to +r_i
            for (offset = -7; offset <= 7; offset = offset + 1) begin
                if ((offset >= -l_i) && (offset <= r_i)) begin
                    idx = center_i + offset;
                    idx = wrap_idx(idx, n_val);
                    parity = parity ^ ((mask >> idx) & 1);
                end
            end
            segment_parity = parity;
        end
    endfunction

    // Combinational logic to count valid assignments
    always @* begin
        count = 32'd0;

        // Edge case: if n == 0, no children; define result as 0
        if (n == 0) begin
            count = 32'd0;
        end else begin
            // Enumerate all 256 possible assignments
            for (assign_mask = 0; assign_mask < 256; assign_mask = assign_mask + 1) begin
                reg valid;
                reg seg_p;
                integer ci;

                valid = 1'b1;

                // Only first n children are considered; top 8-n bits are irrelevant
                // Check each constraint i in [0, n-1]
                for (ci = 0; ci < 8; ci = ci + 1) begin
                    if (ci < n) begin
                        seg_p = segment_parity(ci, l_array[ci], r_array[ci], n, assign_mask);
                        if (seg_p !== x_array[ci]) begin
                            valid = 1'b0;
                        end
                    end
                end

                if (valid) begin
                    count = count + 32'd1;
                    if (count >= MOD)
                        count = count - MOD;
                end
            end
        end
    end

    assign result = count;

endmodule