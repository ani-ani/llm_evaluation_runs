module count_matching_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1_i [0:7],
    input wire [7:0] arr2_i [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] count_reg;
    reg done_next;
    
    // Internal comparator logic
    wire match;
    assign match = (arr1_i[index] == arr2_i[index]);

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 4'd0;
            result <= 16'd0;
            count_reg <= 16'd0;
            done <= 1'b0;
        end else begin
            done <= done_next;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        if (len == 4'd0) begin
                            // Handle zero length immediately
                            state <= DONE;
                            index <= 4'd0;
                            count_reg <= 16'd0;
                        end else begin
                            state <= COMPARE;
                            index <= 4'd0;
                            count_reg <= 16'd0;
                        end
                    end
                end
                
                COMPARE: begin
                    // Increment index
                    index <= index + 4'd1;
                    
                    // Add match if elements are equal
                    if (match) begin
                        count_reg <= count_reg + 16'd1;
                    end
                    
                    // Check if we've processed all elements
                    if (index == (len - 4'd1)) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Copy count to output result
                    result <= count_reg;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for done signal
    always @(*) begin
        case (state)
            IDLE: done_next = 1'b0;
            COMPARE: done_next = 1'b0;
            DONE: done_next = 1'b1;
            default: done_next = 1'b0;
        endcase
    end

endmodule