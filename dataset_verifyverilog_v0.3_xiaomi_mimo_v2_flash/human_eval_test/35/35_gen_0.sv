module max_element (
    input clk,
    input rst_n,
    input start,
    input [7:0] len,
    input [7:0] data [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;          // Counter for array index (max 8)
    reg [7:0] current_max;      // Current maximum value (signed)
    reg [7:0] next_element;     // Next element to compare
    
    // Wires for signed comparison
    wire signed [7:0] result_signed = current_max;
    wire signed [7:0] next_signed = next_element;
    wire is_greater = (next_signed > result_signed);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            counter <= 3'd0;
            current_max <= 8'd0;
            next_element <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && (len > 8'd0)) begin
                        // Initialize with first element
                        current_max <= data[0];
                        counter <= 3'd1;  // Start comparing from index 1
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Get next element from array
                    case (counter)
                        3'd1: next_element <= data[1];
                        3'd2: next_element <= data[2];
                        3'd3: next_element <= data[3];
                        3'd4: next_element <= data[4];
                        3'd5: next_element <= data[5];
                        3'd6: next_element <= data[6];
                        3'd7: next_element <= data[7];
                        default: next_element <= data[0];
                    endcase

                    // Compare and update maximum
                    if (is_greater) begin
                        current_max <= next_element;
                    end

                    // Increment counter
                    counter <= counter + 3'd1;

                    // Check if we've processed all elements
                    // len is 8-bit, but counter is 3-bit (max 8)
                    if (counter >= len[2:0]) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= current_max;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule