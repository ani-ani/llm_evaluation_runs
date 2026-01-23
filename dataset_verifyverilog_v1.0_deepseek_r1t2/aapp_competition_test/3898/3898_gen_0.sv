module statue_rearrangement (
    input [63:0] a_flat,
    input [63:0] b_flat,
    output result
);
    wire [7:0] a [0:7];
    wire [7:0] b [0:7];
    
    generate
        genvar g;
        for (g=0; g<8; g=g+1) begin : extract_array
            assign a[g] = a_flat[g*8 +: 8];
            assign b[g] = b_flat[g*8 +: 8];
        end
    endgenerate
    
    reg [7:0] a_no_zero [0:6];
    reg [7:0] b_no_zero [0:6];
    
    integer i, j;
    always @(*) begin
        j = 3'd0;
        for (i=0; i<8; i=i+1) begin
            if (a[i] != 8'd0) begin
                a_no_zero[j] = a[i];
                j = j + 1;
            end
        end
    end
    
    always @(*) begin
        j = 3'd0;
        for (i=0; i<8; i=i+1) begin
            if (b[i] != 8'd0) begin
                b_no_zero[j] = b[i];
                j = j + 1;
            end
        end
    end
    
    reg [2:0] k;
    always @(*) begin
        k = 3'd0;
        if (a_no_zero[0] == b_no_zero[0]) k = 3'd0;
        else if (a_no_zero[1] == b_no_zero[0]) k = 3'd1;
        else if (a_no_zero[2] == b_no_zero[0]) k = 3'd2;
        else if (a_no_zero[3] == b_no_zero[0]) k = 3'd3;
        else if (a_no_zero[4] == b_no_zero[0]) k = 3'd4;
        else if (a_no_zero[5] == b_no_zero[0]) k = 3'd5;
        else if (a_no_zero[6] == b_no_zero[0]) k = 3'd6;
    end
    
    wire [7:0] a_rotated [0:6];
    wire [6:0] match;
    
    generate
        genvar gi;
        for (gi=0; gi<7; gi=gi+1) begin : rotation
            localparam [2:0] idx = (gi < (7 - k)) ? (k + gi) : (gi - (7 - k));
            assign a_rotated[gi] = a_no_zero[idx];
            assign match[gi] = (a_rotated[gi] == b_no_zero[gi]);
        end
    endgenerate
    
    assign result = &match;
endmodule