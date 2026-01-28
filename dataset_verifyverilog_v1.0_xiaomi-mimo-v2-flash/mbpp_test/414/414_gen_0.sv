module overlapping_check (
    input wire [7:0] arr_a_0,
    input wire [7:0] arr_a_1,
    input wire [7:0] arr_a_2,
    input wire [7:0] arr_a_3,
    input wire [7:0] arr_a_4,
    input wire [7:0] arr_a_5,
    input wire [7:0] arr_a_6,
    input wire [7:0] arr_a_7,
    input wire [7:0] arr_b_0,
    input wire [7:0] arr_b_1,
    input wire [7:0] arr_b_2,
    input wire [7:0] arr_b_3,
    input wire [7:0] arr_b_4,
    input wire [7:0] arr_b_5,
    input wire [7:0] arr_b_6,
    input wire [7:0] arr_b_7,
    input wire [3:0] len_a,
    input wire [3:0] len_b,
    output reg overlapping
);

    // State definitions for FSM
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] SETUP_A   = 4'd1;
    localparam [3:0] COMPARE_B = 4'd2;
    localparam [3:0] NEXT_A    = 4'd3;
    localparam [3:0] DONE      = 4'd4;
    localparam [3:0] FOUND     = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] idx_a;
    reg [3:0] idx_b;
    reg [7:0] current_a;
    reg match_found;
    reg [7:0] current_b;
    reg [3:0] cycle_count;
    
    // Helper signals for current element values
    reg [7:0] a_val;
    reg [7:0] b_val;
    
    // Combinational block to get array values based on index
    always @(*) begin
        case (idx_a)
            4'd0: a_val = arr_a_0;
            4'd1: a_val = arr_a_1;
            4'd2: a_val = arr_a_2;
            4'd3: a_val = arr_a_3;
            4'd4: a_val = arr_a_4;
            4'd5: a_val = arr_a_5;
            4'd6: a_val = arr_a_6;
            4'd7: a_val = arr_a_7;
            default: a_val = 8'd0;
        endcase
        
        case (idx_b)
            4'd0: b_val = arr_b_0;
            4'd1: b_val = arr_b_1;
            4'd2: b_val = arr_b_2;
            4'd3: b_val = arr_b_3;
            4'd4: b_val = arr_b_4;
            4'd5: b_val = arr_b_5;
            4'd6: b_val = arr_b_6;
            4'd7: b_val = arr_b_7;
            default: b_val = 8'd0;
        endcase
    end

    // Sequential FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            overlapping <= 1'b0;
            idx_a <= 4'd0;
            idx_b <= 4'd0;
            current_a <= 8'd0;
            current_b <= 8'd0;
            match_found <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    overlapping <= 1'b0;
                    idx_a <= 4'd0;
                    idx_b <= 4'd0;
                    match_found <= 1'b0;
                    cycle_count <= 4'd0;
                    if (len_a > 4'd0 && len_b > 4'd0) begin
                        state <= SETUP_A;
                    end else begin
                        state <= DONE;
                    end
                end
                
                SETUP_A: begin
                    if (idx_a < len_a) begin
                        current_a <= a_val;
                        idx_b <= 4'd0;
                        state <= COMPARE_B;
                    end else begin
                        state <= DONE;
                    end
                end
                
                COMPARE_B: begin
                    if (idx_b < len_b) begin
                        current_b <= b_val;
                        if (a_val == b_val) begin
                            match_found <= 1'b1;
                            state <= FOUND;
                        end else begin
                            state <= NEXT_A;
                        end
                    end else begin
                        state <= NEXT_A;
                    end
                end
                
                NEXT_A: begin
                    if (idx_a < len_a) begin
                        idx_a <= idx_a + 4'd1;
                        state <= SETUP_A;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    overlapping <= match_found;
                    state <= IDLE;
                end
                
                FOUND: begin
                    overlapping <= 1'b1;
                    state <= DONE;
                end
                
                default: begin
                    state <= IDLE;
                    overlapping <= 1'b0;
                end
            endcase
        end
    end

endmodule