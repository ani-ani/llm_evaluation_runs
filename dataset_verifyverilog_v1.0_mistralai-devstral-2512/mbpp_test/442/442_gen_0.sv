module ratio_calculator(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DIVIDING = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] index;           // Array index counter
    reg [3:0] pos_count;       // Positive number counter
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd20;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            pos_count <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COUNTING;
                        index <= 4'd0;
                        pos_count <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is positive
                    if (arr[index][7] == 1'b0 && arr[index][6:0] != 7'd0) begin
                        pos_count <= pos_count + 4'd1;
                    end
                    
                    // Move to next element or finish counting
                    if (index == len - 4'd1) begin
                        next_state <= DIVIDING;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= COUNTING;
                    end
                end

                DIVIDING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate ratio: (pos_count << 8) / len
                    if (len != 4'd0) begin
                        result <= (pos_count * 8'd256) / len;
                    end else begin
                        result <= 16'd0;
                    end
                    
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule