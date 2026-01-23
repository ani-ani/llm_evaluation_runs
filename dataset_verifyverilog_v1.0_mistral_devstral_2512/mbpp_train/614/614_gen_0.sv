module cumulative_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input: 3 tuples, each up to 3 elements
    // tuple_0: 3 elements, tuple_1: 3 elements, tuple_2: 3 elements
    input wire [7:0] tuple_0_0, tuple_0_1, tuple_0_2,
    input wire [7:0] tuple_1_0, tuple_1_1, tuple_1_2,
    input wire [7:0] tuple_2_0, tuple_2_1, tuple_2_2,
    
    // Valid element counts per tuple (1-3)
    input wire [1:0] len_0, len_1, len_2,
    
    output reg [15:0] result,
    output reg done
);

    // State machine
    reg [2:0] state;
    reg [1:0] tuple_idx;
    reg [1:0] elem_idx;
    reg [15:0] accumulator;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SUM_TUPLE0 = 3'd1;
    localparam [2:0] SUM_TUPLE1 = 3'd2;
    localparam [2:0] SUM_TUPLE2 = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    // Access current element based on tuple and element index
    wire [7:0] current_element;
    assign current_element = (
        (tuple_idx == 2'd0) ? (
            (elem_idx == 2'd0) ? tuple_0_0 :
            (elem_idx == 2'd1) ? tuple_0_1 :
            tuple_0_2
        ) :
        (tuple_idx == 2'd1) ? (
            (elem_idx == 2'd0) ? tuple_1_0 :
            (elem_idx == 2'd1) ? tuple_1_1 :
            tuple_1_2
        ) :
        (
            (elem_idx == 2'd0) ? tuple_2_0 :
            (elem_idx == 2'd1) ? tuple_2_1 :
            tuple_2_2
        )
    );
    
    // Get valid length for current tuple
    wire [1:0] current_len;
    assign current_len = (
        (tuple_idx == 2'd0) ? len_0 :
        (tuple_idx == 2'd1) ? len_1 :
        len_2
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            accumulator <= 16'd0;
            tuple_idx <= 2'd0;
            elem_idx <= 2'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= SUM_TUPLE0;
                        accumulator <= 16'd0;
                        tuple_idx <= 2'd0;
                        elem_idx <= 2'd0;
                    end
                end
                
                SUM_TUPLE0, SUM_TUPLE1, SUM_TUPLE2: begin
                    if (elem_idx < current_len) begin
                        // Add current element to accumulator
                        accumulator <= accumulator + current_element;
                        elem_idx <= elem_idx + 1'b1;
                    end else begin
                        // Move to next tuple or finish
                        elem_idx <= 2'd0;
                        tuple_idx <= tuple_idx + 1'b1;
                        
                        if (state == SUM_TUPLE2) begin
                            result <= accumulator;
                            state <= DONE;
                        end else if (state == SUM_TUPLE1) begin
                            state <= SUM_TUPLE2;
                        end else begin
                            state <= SUM_TUPLE1;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule