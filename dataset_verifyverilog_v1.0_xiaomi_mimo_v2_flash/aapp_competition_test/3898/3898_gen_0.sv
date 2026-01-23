module statue_rearrangement (
    input [63:0] a_flat,
    input [63:0] b_flat,
    output reg result
);
    // Extract arrays using unpacked arrays (Icarus Verilog compatible)
    wire [7:0] a [0:7];
    wire [7:0] b [0:7];
    
    // Manual extraction to avoid generate block if not supported
    assign a[0] = a_flat[7:0];
    assign a[1] = a_flat[15:8];
    assign a[2] = a_flat[23:16];
    assign a[3] = a_flat[31:24];
    assign a[4] = a_flat[39:32];
    assign a[5] = a_flat[47:40];
    assign a[6] = a_flat[55:48];
    assign a[7] = a_flat[63:56];
    
    assign b[0] = b_flat[7:0];
    assign b[1] = b_flat[15:8];
    assign b[2] = b_flat[23:16];
    assign b[3] = b_flat[31:24];
    assign b[4] = b_flat[39:32];
    assign b[5] = b_flat[47:40];
    assign b[6] = b_flat[55:48];
    assign b[7] = b_flat[63:56];
    
    // Step 1: Form arrays without zeros (always combinational)
    reg [7:0] a_no_zero [0:6];
    reg [7:0] b_no_zero [0:6];
    integer i, j;
    
    always @(*) begin
        // Form a_no_zero
        j = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (a[i] != 8'd0) begin
                a_no_zero[j] = a[i];
                j = j + 1;
            end
        end
        
        // Form b_no_zero
        j = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (b[i] != 8'd0) begin
                b_no_zero[j] = b[i];
                j = j + 1;
            end
        end
    end
    
    // Step 2: Find rotation index k in a_no_zero for b_no_zero[0]
    reg [2:0] k;
    always @(*) begin
        k = 3'd0; // Default
        for (i = 0; i < 7; i = i + 1) begin
            if (a_no_zero[i] == b_no_zero[0]) begin
                k = i;
            end
        end
    end
    
    // Step 3: Check if b_no_zero is a rotation of a_no_zero
    always @(*) begin
        result = 1'b1; // Assume match
        for (i = 0; i < 7; i = i + 1) begin
            reg [2:0] idx;
            if (k + i < 7) begin
                idx = k + i;
            end else begin
                idx = k + i - 7;
            end
            if (a_no_zero[idx] != b_no_zero[i]) begin
                result = 1'b0;
            end
        end
    end
endmodule