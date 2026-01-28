module check_tuple_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] search_value,
    input wire [7:0] tuple_data[0:15],
    input wire [4:0] tuple_len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [4:0] index;
    reg found;
    reg done_pulse;

    // Maximum iterations: 16 (tuple_len max) + 1 cycle
    localparam [4:0] MAX_INDEX = 5'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 5'd0;
            found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            done_pulse <= 1'b0;
        end else begin
            // Default outputs
            done <= 1'b0;
            done_pulse <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Start new search
                        index <= 5'd0;
                        found <= 1'b0;
                        state <= SEARCHING;
                    end
                end

                SEARCHING: begin
                    // Check if we've reached the end
                    if (index >= tuple_len) begin
                        // Search complete
                        result <= found;
                        done <= 1'b1;
                        done_pulse <= 1'b1;
                        state <= DONE;
                    end else begin
                        // Compare current element
                        if (tuple_data[index] == search_value) begin
                            found <= 1'b1;
                        end
                        // Increment index (continue scanning even if found)
                        index <= index + 5'd1;
                    end
                end

                DONE: begin
                    // Done pulse already sent, return to IDLE
                    state <= IDLE;
                    // Reset internal state
                    index <= 5'd0;
                    found <= 1'b0;
                end

                default: begin
                    state <= IDLE;
                    index <= 5'd0;
                    found <= 1'b0;
                end
            endcase
        end
    end

endmodule