module fix_spaces (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] text_in,
    input wire [3:0] len_in,
    output reg [127:0] text_out,
    output reg [3:0] len_out,
    output reg done
);

    // State Machine Definition
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_PROC = 3'd1; // Process characters
    localparam [2:0] FLUSH      = 3'd2; // Flush remaining spaces
    localparam [2:0] WRITE_OUT  = 3'd3; // Transfer buffer to output
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [3:0] i;              // Input character index (0 to len_in-1)
    reg [3:0] out_idx;        // Output buffer index (0 to 15)
    reg [3:0] space_cnt;      // Consecutive space counter
    reg [127:0] out_buffer;   // Internal output buffer
    reg [3:0] computed_len;   // Calculated output length
    
    // Constants
    localparam [7:0] SPACE  = 8'h20;
    localparam [7:0] UNDER  = 8'h5F;
    localparam [7:0] DASH   = 8'h2D;

    // Helper signal for current input character
    wire [7:0] current_char;
    assign current_char = text_in[i * 8 +: 8];

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            text_out <= 128'd0;
            len_out <= 4'd0;
            done <= 1'b0;
            i <= 4'd0;
            out_idx <= 4'd0;
            space_cnt <= 4'd0;
            out_buffer <= 128'd0;
            computed_len <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    out_idx <= 4'd0;
                    space_cnt <= 4'd0;
                    if (start) begin
                        state <= READ_PROC;
                    end else begin
                        state <= IDLE;
                    end
                end

                READ_PROC: begin
                    if (i < len_in) begin
                        // Check current character
                        if (current_char == SPACE) begin
                            // Increment space counter
                            space_cnt <= space_cnt + 4'd1;
                            i <= i + 4'd1;
                            state <= READ_PROC;
                        end else begin
                            // Non-space character detected
                            // Flush spaces first
                            if (space_cnt > 4'd0) begin
                                // Determine what to write based on count
                                if (space_cnt == 4'd1) begin
                                    // Write single underscore
                                    out_buffer[out_idx * 8 +: 8] <= UNDER;
                                    out_idx <= out_idx + 4'd1;
                                end else if (space_cnt == 4'd2) begin
                                    // Write two underscores
                                    out_buffer[out_idx * 8 +: 8] <= UNDER;
                                    out_buffer[(out_idx + 4'd1) * 8 +: 8] <= UNDER;
                                    out_idx <= out_idx + 4'd2;
                                end else begin // space_cnt >= 3
                                    // Write single dash
                                    out_buffer[out_idx * 8 +: 8] <= DASH;
                                    out_idx <= out_idx + 4'd1;
                                end
                                space_cnt <= 4'd0;
                                // Stay in state to write the actual character in next cycle
                                state <= READ_PROC; 
                            end else begin
                                // No spaces to flush, write character immediately
                                out_buffer[out_idx * 8 +: 8] <= current_char;
                                out_idx <= out_idx + 4'd1;
                                i <= i + 4'd1;
                                state <= READ_PROC;
                            end
                        end
                    end else begin
                        // End of input string reached
                        // Check if we have trailing spaces
                        if (space_cnt > 4'd0) begin
                            state <= FLUSH;
                        end else begin
                            computed_len <= out_idx;
                            state <= WRITE_OUT;
                        end
                    end
                end

                FLUSH: begin
                    // Handle trailing spaces
                    if (space_cnt == 4'd1) begin
                        out_buffer[out_idx * 8 +: 8] <= UNDER;
                        out_idx <= out_idx + 4'd1;
                    end else if (space_cnt == 4'd2) begin
                        out_buffer[out_idx * 8 +: 8] <= UNDER;
                        out_buffer[(out_idx + 4'd1) * 8 +: 8] <= UNDER;
                        out_idx <= out_idx + 4'd2;
                    end else if (space_cnt >= 4'd3) begin
                        out_buffer[out_idx * 8 +: 8] <= DASH;
                        out_idx <= out_idx + 4'd1;
                    end
                    computed_len <= out_idx; // Note: out_idx was not incremented before this block logic
                    state <= WRITE_OUT;
                    
                    // Correcting computed_len logic for edge case handling:
                    // Since out_idx wasn't updated inside this combinational-style block in the register block above,
                    // we need to do it carefully.
                    // Actually, let's restructure FLUSH to be single-cycle if possible, or use next_state logic.
                    // Given the sequential nature, we can calculate the new length based on current space_cnt.
                    if (space_cnt == 4'd1) computed_len <= out_idx + 4'd1;
                    else if (space_cnt == 4'd2) computed_len <= out_idx + 4'd2;
                    else if (space_cnt >= 4'd3) computed_len <= out_idx + 4'd1;
                    else computed_len <= out_idx;
                    
                    // Clear space_cnt to be safe
                    space_cnt <= 4'd0;
                end

                WRITE_OUT: begin
                    text_out <= out_buffer;
                    len_out <= computed_len;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule