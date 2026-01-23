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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] current_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_out <= 16'd0;
            pair_valid <= 1'b0;
            done <= 1'b0;
            pair_index <= 3'd0;
            current_index <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    pair_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= GENERATE;
                        current_index <= 3'd0;
                    end
                end
                
                GENERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Generate current pair
                    pair_valid <= 1'b1;
                    pair_index <= current_index;
                    
                    // Select pair based on current index
                    case (current_index)
                        3'd0: pair_out <= {arr_0, arr_1};
                        3'd1: pair_out <= {arr_1, arr_2};
                        3'd2: pair_out <= {arr_2, arr_3};
                        3'd3: pair_out <= {arr_3, arr_4};
                        3'd4: pair_out <= {arr_4, arr_5};
                        3'd5: pair_out <= {arr_5, arr_6};
                        3'd6: pair_out <= {arr_6, arr_7};
                        default: pair_out <= 16'd0;
                    endcase
                    
                    // Move to next index or finish
                    if (current_index == (len - 4'd2) || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        current_index <= current_index + 3'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    pair_valid <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule