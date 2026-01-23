module exam_helper (
    input clk,
    input rst_n,
    input valid_in,
    input op,           // 0: D, 1: P
    input [31:0] A_in,
    input [31:0] B_in,
    input [3:0] idx_in, // for P: student index (1-16)
    output reg valid_out,
    output reg [31:0] result  // for P: found index (1-16), or 0 for NE
);

parameter MAX_STUDENTS = 16;

reg [31:0] A_reg [0:MAX_STUDENTS-1];
reg [31:0] B_reg [0:MAX_STUDENTS-1];
reg [4:0] count;  // number of students stored (0 to 16)

// Combinational search logic
reg [3:0] candidate_index;
reg candidate_found;
reg [31:0] candidate_B_diff, candidate_A_diff;
reg [31:0] A_q, B_q;
reg [31:0] B_diff, A_diff;
integer j;

always @(*) begin
    candidate_index = 0;
    candidate_found = 0;
    candidate_B_diff = 32'hFFFF_FFFF;
    candidate_A_diff = 32'hFFFF_FFFF;
    
    if (idx_in >= 1 && idx_in <= count) begin
        A_q = A_reg[idx_in-1];
        B_q = B_reg[idx_in-1];
        
        for (j = 0; j < MAX_STUDENTS; j = j + 1) begin
            if (j < count && j != (idx_in-1)) begin
                if (A_reg[j] >= A_q && B_reg[j] >= B_q) begin
                    B_diff = B_reg[j] - B_q;
                    A_diff = A_reg[j] - A_q;
                    if (!candidate_found || 
                        (B_diff < candidate_B_diff) || 
                        (B_diff == candidate_B_diff && A_diff < candidate_A_diff)) begin
                        candidate_index = j;
                        candidate_B_diff = B_diff;
                        candidate_A_diff = A_diff;
                        candidate_found = 1;
                    end
                end
            end
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 0;
        valid_out <= 0;
        result <= 0;
    end else begin
        valid_out <= 0;
        if (valid_in) begin
            if (op == 0) begin  // D operation
                if (count < MAX_STUDENTS) begin
                    A_reg[count] <= A_in;
                    B_reg[count] <= B_in;
                    count <= count + 1;
                end
            end else if (op == 1) begin  // P operation
                result <= candidate_found ? (candidate_index + 1) : 0;
                valid_out <= 1;
            end
        end
    end
end

endmodule