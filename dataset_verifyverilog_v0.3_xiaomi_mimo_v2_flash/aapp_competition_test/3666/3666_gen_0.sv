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
reg [3:0] idx;
reg [7:0] num [0:11];
reg [7:0] den [0:11];

// Processing registers
reg [7:0] num1_reg, num2_reg;
reg [1:0] num_count;
reg [7:0] den_table_0, den_table_1, den_table_2, den_table_3, den_table_4, den_table_5;
reg [2:0] den_count;
reg error_flag;
reg [3:0] proc_idx;
reg [3:0] i;

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
        den_table_0 <= 8'd0;
        den_table_1 <= 8'd0;
        den_table_2 <= 8'd0;
        den_table_3 <= 8'd0;
        den_table_4 <= 8'd0;
        den_table_5 <= 8'd0;
        for (i = 0; i < 12; i = i + 1) begin
            num[i] <= 8'd0;
            den[i] <= 8'd0;
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    idx <= 4'd0;
                    num_count <= 2'd0;
                    den_count <= 3'd0;
                    error_flag <= 1'b0;
                    proc_idx <= 4'd0;
                    num1_reg <= 8'd0;
                    num2_reg <= 8'd0;
                    den_table_0 <= 8'd0;
                    den_table_1 <= 8'd0;
                    den_table_2 <= 8'd0;
                    den_table_3 <= 8'd0;
                    den_table_4 <= 8'd0;
                    den_table_5 <= 8'd0;
                end
            end
            
            LOAD: begin
                if (idx < 12) begin
                    case (idx)
                        4'd0: begin num[0] <= n0; den[0] <= d0; end
                        4'd1: begin num[1] <= n1; den[1] <= d1; end
                        4'd2: begin num[2] <= n2; den[2] <= d2; end
                        4'd3: begin num[3] <= n3; den[3] <= d3; end
                        4'd4: begin num[4] <= n4; den[4] <= d4; end
                        4'd5: begin num[5] <= n5; den[5] <= d5; end
                        4'd6: begin num[6] <= n6; den[6] <= d6; end
                        4'd7: begin num[7] <= n7; den[7] <= d7; end
                        4'd8: begin num[8] <= n8; den[8] <= d8; end
                        4'd9: begin num[9] <= n9; den[9] <= d9; end
                        4'd10: begin num[10] <= n10; den[10] <= d10; end
                        4'd11: begin num[11] <= n11; den[11] <= d11; end
                    endcase
                    idx <= idx + 4'd1;
                end
            end
            
            PROCESS: begin
                if (proc_idx < 12) begin
                    // Process ratio at proc_idx
                    if (num_count < 2 && num[proc_idx] != num1_reg && num[proc_idx] != num2_reg) begin
                        if (num_count == 0) begin
                            num1_reg <= num[proc_idx];
                            num_count <= 2'd1;
                        end else if (num_count == 1) begin
                            num2_reg <= num[proc_idx];
                            num_count <= 2'd2;
                        end
                    end else if (num_count == 2 && num[proc_idx] != num1_reg && num[proc_idx] != num2_reg) begin
                        error_flag <= 1'b1;
                    end
                    
                    // Check denominator
                    if (den_count < 6) begin
                        // Check if denominator already in table
                        if (den[proc_idx] != den_table_0 && den[proc_idx] != den_table_1 &&
                            den[proc_idx] != den_table_2 && den[proc_idx] != den_table_3 &&
                            den[proc_idx] != den_table_4 && den[proc_idx] != den_table_5) begin
                            if (den_count == 0) den_table_0 <= den[proc_idx];
                            else if (den_count == 1) den_table_1 <= den[proc_idx];
                            else if (den_count == 2) den_table_2 <= den[proc_idx];
                            else if (den_count == 3) den_table_3 <= den[proc_idx];
                            else if (den_count == 4) den_table_4 <= den[proc_idx];
                            else if (den_count == 5) den_table_5 <= den[proc_idx];
                            den_count <= den_count + 3'd1;
                        end
                    end else begin
                        // Already have 6 denominators, check if this one matches
                        if (den[proc_idx] != den_table_0 && den[proc_idx] != den_table_1 &&
                            den[proc_idx] != den_table_2 && den[proc_idx] != den_table_3 &&
                            den[proc_idx] != den_table_4 && den[proc_idx] != den_table_5) begin
                            error_flag <= 1'b1;
                        end
                    end
                    
                    proc_idx <= proc_idx + 4'd1;
                end else if (proc_idx == 12) begin
                    // Final check
                    if (den_count != 6 || error_flag || num_count == 0) begin
                        error_flag <= 1'b1;
                    end
                    proc_idx <= proc_idx + 4'd1;
                end
            end
            
            OUTPUT: begin
                front1 <= {6'd0, num1_reg};
                front2 <= (num_count == 1) ? {6'd0, num1_reg} : {6'd0, num2_reg};
                rear1 <= {6'd0, den_table_0};
                rear2 <= {6'd0, den_table_1};
                rear3 <= {6'd0, den_table_2};
                rear4 <= {6'd0, den_table_3};
                rear5 <= {6'd0, den_table_4};
                rear6 <= {6'd0, den_table_5};
                valid <= 1'b1;
                done <= 1'b1;
            end
            
            ERROR: begin
                valid <= 1'b0;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
                valid <= 1'b0;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: if (idx == 12) next_state = PROCESS;
        PROCESS: begin
            if (proc_idx > 12) begin
                if (error_flag) next_state = ERROR;
                else next_state = OUTPUT;
            end
        end
        OUTPUT, ERROR: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

endmodule