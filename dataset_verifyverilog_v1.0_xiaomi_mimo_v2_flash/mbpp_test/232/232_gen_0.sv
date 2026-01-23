module top (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] n,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg done
);

    // Maximum constants
    parameter MAX_SIZE = 8;
    parameter MAX_N = 5;
    localparam MAX_CYCLES = 16'd500;
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] SWAP = 3'd3;
    localparam [2:0] NEXT_PAIR = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;
    localparam [2:0] FINISH = 3'd6;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] sorted_0, sorted_1, sorted_2, sorted_3;
    reg [7:0] sorted_4, sorted_5, sorted_6, sorted_7;
    reg [3:0] i, j;
    reg [3:0] output_idx;
    reg [15:0] cycle_count;
    reg [7:0] temp;
    
    // Combinational signals
    wire swap;
    assign swap = (j < 4'd7);
    wire swap_needed;
    assign swap_needed = (
        (j == 4'd0 && sorted_0 < sorted_1) ||
        (j == 4'd1 && sorted_1 < sorted_2) ||
        (j == 4'd2 && sorted_2 < sorted_3) ||
        (j == 4'd3 && sorted_3 < sorted_4) ||
        (j == 4'd4 && sorted_4 < sorted_5) ||
        (j == 4'd5 && sorted_5 < sorted_6) ||
        (j == 4'd6 && sorted_6 < sorted_7)
    );
    
    wire swap_done;
    assign swap_done = (j >= 4'd7);
    
    wire sort_complete;
    assign sort_complete = (i >= 4'd7);
    
    wire output_done;
    assign output_done = (output_idx >= n || output_idx >= 5);
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sorted_0 <= 8'd0;
            sorted_1 <= 8'd0;
            sorted_2 <= 8'd0;
            sorted_3 <= 8'd0;
            sorted_4 <= 8'd0;
            sorted_5 <= 8'd0;
            sorted_6 <= 8'd0;
            sorted_7 <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            output_idx <= 4'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            temp <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    sorted_0 <= arr_0;
                    sorted_1 <= arr_1;
                    sorted_2 <= arr_2;
                    sorted_3 <= arr_3;
                    sorted_4 <= arr_4;
                    sorted_5 <= arr_5;
                    sorted_6 <= arr_6;
                    sorted_7 <= arr_7;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= COMPARE;
                end
                
                COMPARE: begin
                    if (swap_needed) begin
                        state <= SWAP;
                    end else begin
                        state <= NEXT_PAIR;
                    end
                end
                
                SWAP: begin
                    // Swap elements based on j index
                    case (j)
                        4'd0: begin
                            temp <= sorted_0;
                            sorted_0 <= sorted_1;
                            sorted_1 <= temp;
                        end
                        4'd1: begin
                            temp <= sorted_1;
                            sorted_1 <= sorted_2;
                            sorted_2 <= temp;
                        end
                        4'd2: begin
                            temp <= sorted_2;
                            sorted_2 <= sorted_3;
                            sorted_3 <= temp;
                        end
                        4'd3: begin
                            temp <= sorted_3;
                            sorted_3 <= sorted_4;
                            sorted_4 <= temp;
                        end
                        4'd4: begin
                            temp <= sorted_4;
                            sorted_4 <= sorted_5;
                            sorted_5 <= temp;
                        end
                        4'd5: begin
                            temp <= sorted_5;
                            sorted_5 <= sorted_6;
                            sorted_6 <= temp;
                        end
                        4'd6: begin
                            temp <= sorted_6;
                            sorted_6 <= sorted_7;
                            sorted_7 <= temp;
                        end
                        default: begin
                            sorted_0 <= sorted_0;
                            sorted_1 <= sorted_1;
                            sorted_2 <= sorted_2;
                            sorted_3 <= sorted_3;
                            sorted_4 <= sorted_4;
                            sorted_5 <= sorted_5;
                            sorted_6 <= sorted_6;
                            sorted_7 <= sorted_7;
                        end
                    endcase
                    state <= NEXT_PAIR;
                end
                
                NEXT_PAIR: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (swap_done) begin
                        j <= 4'd0;
                        if (sort_complete) begin
                            state <= OUTPUT;
                        end else begin
                            i <= i + 4'd1;
                            state <= COMPARE;
                        end
                    end else begin
                        j <= j + 4'd1;
                        state <= COMPARE;
                    end
                end
                
                OUTPUT: begin
                    if (output_idx < 5) begin
                        case (output_idx)
                            4'd0: result_0 <= sorted_7;
                            4'd1: result_1 <= sorted_6;
                            4'd2: result_2 <= sorted_5;
                            4'd3: result_3 <= sorted_4;
                            4'd4: result_4 <= sorted_3;
                            default: begin
                                result_0 <= result_0;
                                result_1 <= result_1;
                                result_2 <= result_2;
                                result_3 <= result_3;
                                result_4 <= result_4;
                            end
                        endcase
                        if (output_done) begin
                            state <= FINISH;
                        end else begin
                            output_idx <= output_idx + 4'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Prevent infinite loops
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
            end
        end
    end

endmodule