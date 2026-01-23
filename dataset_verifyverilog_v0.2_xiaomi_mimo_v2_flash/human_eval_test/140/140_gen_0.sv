module fix_spaces (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] text_in,
    output reg [127:0] text_out,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] char_idx;      // 0 to 15 for 16 characters
    reg [3:0] space_run_len; // Tracks consecutive spaces seen
    reg [127:0] buffer_out;  // Accumulates output
    reg [3:0] write_idx;     // Tracks index for buffered output
    
    // ASCII definitions
    localparam SPACE = 8'h20;
    localparam UNDERSCORE = 8'h5F;
    localparam HYPHEN = 8'h2D;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            text_out <= 128'd0;
            char_idx <= 4'd0;
            space_run_len <= 4'd0;
            buffer_out <= 128'd0;
            write_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        char_idx <= 4'd0;
                        space_run_len <= 4'd0;
                        write_idx <= 4'd0;
                        buffer_out <= 128'd0;
                    end
                end

                PROCESSING: begin
                    // Read current character from input based on char_idx
                    // Since text_in is fixed 128-bit, we can slice it directly
                    // char_idx 0 corresponds to bits [7:0], char_idx 1 to [15:8], etc.
                    if (text_in[char_idx*8 +: 8] == SPACE) begin
                        // Current char is a space
                        space_run_len <= space_run_len + 1;
                        
                        if (space_run_len == 2) begin
                            // This is the 3rd space (run_len was 2, increment to 3)
                            // Replace the 3rd space with a hyphen.
                            // Note: The 1st and 2nd spaces were previously ignored/stored in run_len.
                            // Now we write one hyphen.
                            buffer_out[write_idx*8 +: 8] <= HYPHEN;
                            write_idx <= write_idx + 1;
                        end
                        // If run_len is 0 or 1 (becoming 1 or 2), we don't write anything yet.
                        // If run_len is >= 2 (becoming >= 3), we already wrote the hyphen for the 3rd.
                        // Any further spaces (4th, 5th...) just increment run_len and write nothing.
                    end else begin
                        // Current char is NOT a space
                        if (space_run_len > 0) begin
                            // We need to flush the pending space run
                            if (space_run_len == 1) begin
                                // Single space -> underscore
                                buffer_out[write_idx*8 +: 8] <= UNDERSCORE;
                                write_idx <= write_idx + 1;
                            end else if (space_run_len == 2) begin
                                // Two spaces -> two underscores
                                buffer_out[write_idx*8 +: 8] <= UNDERSCORE;
                                buffer_out[(write_idx+1)*8 +: 8] <= UNDERSCORE;
                                write_idx <= write_idx + 2;
                            end
                            // If space_run_len >= 3, we already handled the conversion to hyphen.
                            // The logic for >=3 is:
                            // 1st space: run=1, nothing written.
                            // 2nd space: run=2, nothing written.
                            // 3rd space: run=3, hyphen written.
                            // 4th+ spaces: run>3, nothing written.
                            // So if we see a non-space and run_len >= 3, the hyphen is already written.
                            // We just need to reset the counter.
                            
                            space_run_len <= 0;
                        end
                        
                        // Write the non-space character
                        buffer_out[write_idx*8 +: 8] <= text_in[char_idx*8 +: 8];
                        write_idx <= write_idx + 1;
                    end

                    // Increment character index
                    if (char_idx == 15) begin
                        // Last character processed. Check for trailing spaces.
                        if (space_run_len > 0) begin
                            // Flush remaining spaces
                            if (space_run_len == 1) begin
                                buffer_out[write_idx*8 +: 8] <= UNDERSCORE;
                                write_idx <= write_idx + 1;
                            end else if (space_run_len == 2) begin
                                buffer_out[write_idx*8 +: 8] <= UNDERSCORE;
                                buffer_out[(write_idx+1)*8 +: 8] <= UNDERSCORE;
                                write_idx <= write_idx + 2;
                            end
                            // If space_run_len >= 3, the hyphen was written on the 3rd space.
                        end
                        
                        state <= DONE;
                        text_out <= buffer_out; // Register the final output
                        done <= 1'b1;
                    end else begin
                        char_idx <= char_idx + 1;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    // Wait for reset or next start pulse (implied by IDLE behavior)
                    // Explicitly returning to IDLE to latch the start signal properly
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
