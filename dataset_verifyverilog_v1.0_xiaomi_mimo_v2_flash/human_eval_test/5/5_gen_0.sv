module intersperse (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [7:0] delimiter,
    input [3:0] length,
    output reg [7:0] result,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] OUTPUT  = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] counter;          // Tracks position in sequence (0 to 2*length)
    reg output_element;         // Alternating: 1=element, 0=delimiter
    reg [3:0] array_index;      // Index into input array
    reg [3:0] cycle_count;      // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd16; // Safe upper bound (MAX_SIZE*2)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            counter <= 4'd0;
            output_element <= 1'b1;
            array_index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    counter <= 4'd0;
                    output_element <= 1'b1;
                    array_index <= 4'd0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        if (length == 4'd0) begin
                            state <= DONE;
                        end else begin
                            state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Output logic
                    valid <= 1'b1;
                    if (output_element) begin
                        // Output array element
                        result <= arr[array_index];
                    end else begin
                        // Output delimiter
                        result <= delimiter;
                    end
                    
                    // Update counters for next cycle
                    if (output_element) begin
                        output_element <= 1'b0;
                    end else begin
                        output_element <= 1'b1;
                        array_index <= array_index + 4'd1;
                    end
                    
                    // Check completion conditions
                    // Total outputs needed = length (elements) + (length - 1) (delimiters) = 2*length - 1
                    // Counter tracks from 0 to 2*length - 2
                    if (counter >= (2 * length - 2)) begin
                        state <= DONE;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule