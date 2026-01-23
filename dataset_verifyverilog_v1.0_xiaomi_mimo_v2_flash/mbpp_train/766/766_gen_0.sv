module pair_wise(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [15:0] pair_out,
    output reg pair_valid,
    output reg done,
    output reg [2:0] pair_index
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [2:0] current_index;
    reg [3:0] len_reg;
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
            end
            PROCESS: begin
                if (current_index >= len_reg[2:0] - 3'd1)
                    next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_out <= 16'd0;
            pair_valid <= 1'b0;
            done <= 1'b0;
            pair_index <= 3'd0;
            current_index <= 3'd0;
            len_reg <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    pair_out <= 16'd0;
                    pair_valid <= 1'b0;
                    done <= 1'b0;
                    pair_index <= 3'd0;
                    current_index <= 3'd0;
                    len_reg <= 4'd0;
                    
                    if (start && len >= 4'd2) begin
                        len_reg <= len;
                    end
                end
                
                PROCESS: begin
                    if (current_index < len_reg[2:0]) begin
                        pair_valid <= 1'b1;
                        pair_index <= current_index;
                        
                        // Build pair_out based on current_index
                        case (current_index)
                            3'd0: pair_out <= {arr_0, arr_1};
                            3'd1: pair_out <= {arr_1, arr_2};
                            3'd2: pair_out <= {arr_2, arr_3};
                            3'd3: pair_out <= {arr_3, arr_4};
                            3'd4: pair_out <= {arr_4, arr_5};
                            3'd5: pair_out <= {arr_5, arr_6};
                            3'd6: pair_out <= {arr_6, arr_7};
                            default: pair_out <= {arr_0, arr_1};
                        endcase
                        
                        current_index <= current_index + 3'd1;
                    end else begin
                        pair_valid <= 1'b0;
                    end
                end
                
                FINISH: begin
                    pair_valid <= 1'b0;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    pair_out <= 16'd0;
                    pair_valid <= 1'b0;
                    done <= 1'b0;
                    pair_index <= 3'd0;
                    current_index <= 3'd0;
                    len_reg <= 4'd0;
                end
            endcase
        end
    end

endmodule