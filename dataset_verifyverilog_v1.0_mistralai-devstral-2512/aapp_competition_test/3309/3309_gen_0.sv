module EquestriaGamesMedia(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] sectors [0:15],
    input wire [3:0] K_in,
    input wire [3:0] C_in,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE   = 3'd0;
    localparam [2:0] SCAN   = 3'd1;
    localparam [2:0] CHECK  = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] DONE   = 3'd4;

    reg [2:0] state, next_state;

    // Counters and registers
    reg [3:0] start_idx;      // Current starting sector index
    reg [3:0] current_len;    // Current range length being checked
    reg [3:0] company_count; // Number of valid companies found
    reg [15:0] used_sectors;  // Bitmask of used sectors (1=used)
    reg [15:0] color_mask;    // Bitmask of colors in current range

    // Temporary registers for computation
    reg [3:0] temp_color;
    reg [3:0] i, j;
    reg [3:0] max_companies;

    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            start_idx <= 4'd0;
            current_len <= 4'd0;
            company_count <= 4'd0;
            used_sectors <= 16'd0;
            color_mask <= 16'd0;
            max_companies <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= SCAN;
                        start_idx <= 4'd0;
                        company_count <= 4'd0;
                        used_sectors <= 16'd0;
                        max_companies <= 4'd0;
                        cycle_count <= 10'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN: begin
                    // Find next unused sector
                    if (start_idx < 4'd16 && used_sectors[start_idx]) begin
                        start_idx <= start_idx + 4'd1;
                        next_state <= SCAN;
                    end else if (start_idx < 4'd16) begin
                        current_len <= K_in;
                        color_mask <= 16'd0;
                        next_state <= CHECK;
                    end else begin
                        // All sectors processed
                        result <= max_companies;
                        next_state <= DONE;
                    end
                end

                CHECK: begin
                    // Build color mask for current range [start_idx, start_idx+current_len-1]
                    color_mask <= 16'd0;
                    for (i = 4'd0; i < current_len; i = i + 4'd1) begin
                        temp_color <= sectors[(start_idx + i) % 4'd16];
                        color_mask <= color_mask | (16'd1 << temp_color);
                    end

                    // Count distinct colors
                    j <= 4'd0;
                    for (i = 4'd0; i < 16; i = i + 4'd1) begin
                        if (color_mask[i]) begin
                            j <= j + 4'd1;
                        end
                    end

                    // Check if valid range
                    if (j >= C_in) begin
                        // Mark sectors as used
                        for (i = 4'd0; i < current_len; i = i + 4'd1) begin
                            used_sectors[(start_idx + i) % 4'd16] <= 1'b1;
                        end
                        company_count <= company_count + 4'd1;
                        next_state <= UPDATE;
                    end else if (current_len < (4'd16 - start_idx)) begin
                        // Try longer range
                        current_len <= current_len + 4'd1;
                        next_state <= CHECK;
                    end else begin
                        // No valid range found, move to next sector
                        start_idx <= start_idx + 4'd1;
                        next_state <= SCAN;
                    end
                end

                UPDATE: begin
                    // Update max companies if needed
                    if (company_count > max_companies) begin
                        max_companies <= company_count;
                    end

                    // Move to next sector
                    start_idx <= start_idx + 4'd1;
                    next_state <= SCAN;
                end

                DONE: begin
                    done <= 1'b1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule