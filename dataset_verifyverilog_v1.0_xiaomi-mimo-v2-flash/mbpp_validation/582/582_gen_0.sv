module dictionary_check (
    input clk,
    input rst_n,
    input start,
    input [7:0] key,
    input [7:0] value,
    input [1:0] op,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_EMPTY = 3'd1;
    localparam [2:0] INSERT     = 3'd2;
    localparam [2:0] REMOVE     = 3'd3;
    localparam [2:0] CLEAR      = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Operation codes
    localparam [1:0] OP_CHECK_EMPTY = 2'd0;
    localparam [1:0] OP_INSERT      = 2'd1;
    localparam [1:0] OP_REMOVE      = 2'd2;
    localparam [1:0] OP_CLEAR       = 2'd3;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Counter for check_empty operation
    reg [3:0] counter;
    reg counter_reset;
    reg counter_inc;

    // Dictionary storage: 16 entries, each with valid flag and 8-bit value
    reg [0:15] valid_bits;  // Valid flags for entries 0-15
    reg [7:0] values [0:15]; // Value storage for entries 0-15

    // Index derived from key
    wire [3:0] index;
    assign index = key[3:0];

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    case (op)
                        OP_CHECK_EMPTY: next_state = CHECK_EMPTY;
                        OP_INSERT:      next_state = INSERT;
                        OP_REMOVE:      next_state = REMOVE;
                        OP_CLEAR:       next_state = CLEAR;
                        default:        next_state = IDLE;
                    endcase
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK_EMPTY: begin
                // Continue checking until counter reaches 16
                if (counter == 4'd15) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_EMPTY;
                end
            end

            INSERT: begin
                next_state = FINISH;
            end

            REMOVE: begin
                next_state = FINISH;
            end

            CLEAR: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for state and registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            counter <= 4'd0;
            valid_bits <= 16'd0;
            // Reset all value storage
            for (i = 0; i < 16; i = i + 1) begin
                values[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0; // Default done is 0

            case (state)
                IDLE: begin
                    // Clear done when idle and start is handled
                    done <= 1'b0;
                    result <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        case (op)
                            OP_CHECK_EMPTY: begin
                                // Prepare for check_empty
                                // result initially 1 (assuming empty), will be cleared if we find a valid entry
                                result <= 1'b1;
                                counter <= 4'd0;
                            end
                            OP_INSERT: begin
                                // Store value and set valid
                                values[index] <= value;
                                valid_bits[index] <= 1'b1;
                            end
                            OP_REMOVE: begin
                                // Clear valid flag
                                valid_bits[index] <= 1'b0;
                            end
                            OP_CLEAR: begin
                                // Reset all entries
                                valid_bits <= 16'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    values[i] <= 8'd0;
                                end
                            end
                        endcase
                    end
                end

                CHECK_EMPTY: begin
                    // Check current entry
                    if (valid_bits[counter]) begin
                        result <= 1'b0; // Found a valid entry, not empty
                    end
                    counter <= counter + 4'd1;
                end

                INSERT: begin
                    // Already done in IDLE (single cycle logic for insert)
                    done <= 1'b1;
                end

                REMOVE: begin
                    // Already done in IDLE (single cycle logic for remove)
                    done <= 1'b1;
                end

                CLEAR: begin
                    // Already done in IDLE (single cycle logic for clear)
                    done <= 1'b1;
                end

                FINISH: begin
                    done <= 1'b1;
                    // For check_empty, result is already set
                    // For insert/remove/clear, result remains 0 (default)
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    counter <= 4'd0;
                    valid_bits <= 16'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        values[i] <= 8'd0;
                    end
                end
            endcase
        end
    end

endmodule