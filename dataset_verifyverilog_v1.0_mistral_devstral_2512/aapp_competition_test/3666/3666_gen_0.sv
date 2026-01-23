module gear_ratio_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n0, d0,
    input wire [7:0] n1, d1,
    input wire [7:0] n2, d2,
    input wire [7:0] n3, d3,
    input wire [7:0] n4, d4,
    input wire [7:0] n5, d5,
    input wire [7:0] n6, d6,
    input wire [7:0] n7, d7,
    input wire [7:0] n8, d8,
    input wire [7:0] n9, d9,
    input wire [7:0] n10, d10,
    input wire [7:0] n11, d11,
    output reg [13:0] front1, front2,
    output reg [13:0] rear1, rear2, rear3, rear4, rear5, rear6,
    output reg valid,
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD = 3'd1;
localparam [2:0] PROCESS = 3'd2;
localparam [2:0] OUTPUT = 3'd3;
localparam [2:0] ERROR = 3'd4;

reg [2:0] state, next_state;
reg [3:0] idx; // 0-11 for loading
reg [7:0] num [0:11]; // stored numerators
reg [7:0] den [0:11]; // stored denominators

// Processing registers
reg [7:0] num1_reg, num2_reg;
reg [1:0] num_count;
reg [7:0] den_table [0:5]; // 6 denominators
reg [2:0] den_count;
reg error_flag;
reg [3:0] proc_idx; // for processing loop

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 4'd0;
        proc_idx <= 4'd0;
        num1_reg <= 8'd0;
        num2_reg <= 8'd0;
        num_count <= 2'd0;
        den_count <= 3'd0;
        error_flag <= 1'b0;
        front1 <= 14'd0;
        front2 <= 14'd0;
        rear1 <= 14'd0;
        rear2 <= 14'd0;
        rear3 <= 14'd0;
        rear4 <= 14'd0;
        rear5 <= 14'd0;
        rear6 <= 14'd0;
        valid <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    idx <= 4'd0;
                    num_count <= 2'd0;
                    den_count <= 3'd0;
                    error_flag <= 1'b0;
                    proc_idx <= 4'd0;
                    num1_reg <= 8'd0;
                    num2_reg <= 8'd0;
                end
            end
            
            LOAD: begin
                if (idx < 4'd12) begin
                    case (idx)
                        4'd0: begin num[idx] <= n0; den[idx] <= d0; end
                        4'd1: begin num[idx] <= n1; den[idx] <= d1; end
                        4'd2: begin num[idx] <= n2; den[idx] <= d2; end
                        4'd3: begin num[idx] <= n3; den[idx] <= d3; end
                        4'd4: begin num[idx] <= n4; den[idx] <= d4; end
                        4'd5: begin num[idx] <= n5; den[idx] <= d5; end
                        4'd6: begin num[idx] <= n6; den[idx] <= d6; end
                        4'd7: begin num[idx] <= n7; den[idx] <= d7; end
                        4'd8: begin num[idx] <= n8; den[idx] <= d8; end
                        4'd9: begin num[idx] <= n9; den[idx] <= d9; end
                        4'd10: begin num[idx] <= n10; den[idx] <= d10; end
                        4'd11: begin num[idx] <= n11; den[idx] <= d11; end
                    endcase
                    idx <= idx + 4'd1;
                end
            end
            
            PROCESS: begin
                if (proc_idx < 4'd12) begin
                    // Process ratio at proc_idx
                    if (num_count < 2'd2 && num[proc_idx] != num1_reg && num[proc_idx] != num2_reg) begin
                        if (num_count == 2'd0) begin
                            num1_reg <= num[proc_idx];
                            num_count <= 2'd1;
                        end else if (num_count == 2'd1) begin
                            num2_reg <= num[proc_idx];
                            num_count <= 2'd2;
                        end
                    end else if (num_count == 2'd2 && num[proc_idx] != num1_reg && num[proc_idx] != num2_reg) begin
                        error_flag <= 1'b1;
                    end
                    
                    // Check denominator
                    if (den_count < 3'd6) begin
                        // Check if denominator already in table
                        if (den[proc_idx] != den_table[0] && den[proc_idx] != den_table[1] &&
                            den[proc_idx] != den_table[2] && den[proc_idx] != den_table[3] &&
                            den[proc_idx] != den_table[4] && den[proc_idx] != den_table[5]) begin
                            den_table[den_count] <= den[proc_idx];
                            den_count <= den_count + 3'd1;
                        end
                    end else begin
                        // Already have 6 denominators, check if this one matches
                        if (den[proc_idx] != den_table[0] && den[proc_idx] != den_table[1] &&
                            den[proc_idx] != den_table[2] && den[proc_idx] != den_table[3] &&
                            den[proc_idx] != den_table[4] && den[proc_idx] != den_table[5]) begin
                            error_flag <= 1'b1;
                        end
                    end
                    
                    proc_idx <= proc_idx + 4'd1;
                end else if (proc_idx == 4'd12) begin
                    // Final check
                    if (den_count != 3'd6 || error_flag || num_count == 2'd0) begin
                        error_flag <= 1'b1;
                    end
                    proc_idx <= proc_idx + 4'd1;
                end
            end
            
            OUTPUT: begin
                front1 <= num1_reg;
                front2 <= (num_count == 2'd1) ? num1_reg : num2_reg;
                rear1 <= den_table[0];
                rear2 <= den_table[1];
                rear3 <= den_table[2];
                rear4 <= den_table[3];
                rear5 <= den_table[4];
                rear6 <= den_table[5];
                valid <= 1'b1;
                done <= 1'b1;
            end
            
            ERROR: begin
                valid <= 1'b0;
                done <= 1'b1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: if (idx == 4'd12) next_state = PROCESS;
        PROCESS: begin
            if (proc_idx > 4'd12) begin
                if (error_flag) next_state = ERROR;
                else next_state = OUTPUT;
            end
        end
        OUTPUT, ERROR: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

endmodule