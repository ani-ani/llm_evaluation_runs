module adverb_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [127:0] data,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [3:0] scan_idx;      // Current position being scanned
    reg found_flag;           // Flag to indicate match found
    reg [3:0] found_start;    // Store start index when found
    reg [3:0] found_end;      // Store end index when found
    reg [4:0] cycle_count;    // Max 32 cycles (16 positions * 2 checks)
    localparam [4:0] MAX_CYCLES = 5'd31;

    // Helper function to check if a byte is alphabetic
    function automatic is_alpha;
        input [7:0] byte_val;
        reg is_upper, is_lower;
        begin
            is_upper = (byte_val >= 8'd65) && (byte_val <= 8'd90);   // A-Z
            is_lower = (byte_val >= 8'd97) && (byte_val <= 8'd122);  // a-z
            is_alpha = is_upper || is_lower;
        end
    endfunction

    // Combinational logic to extract bytes from packed array
    wire [7:0] char_at [0:15];
    assign char_at[0] = data[7:0];
    assign char_at[1] = data[15:8];
    assign char_at[2] = data[23:16];
    assign char_at[3] = data[31:24];
    assign char_at[4] = data[39:32];
    assign char_at[5] = data[47:40];
    assign char_at[6] = data[55:48];
    assign char_at[7] = data[63:56];
    assign char_at[8] = data[71:64];
    assign char_at[9] = data[79:72];
    assign char_at[10] = data[87:80];
    assign char_at[11] = data[95:88];
    assign char_at[12] = data[103:96];
    assign char_at[13] = data[111:104];
    assign char_at[14] = data[119:112];
    assign char_at[15] = data[127:120];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_pos <= 4'd0;
            end_pos <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            scan_idx <= 4'd0;
            found_flag <= 1'b0;
            found_start <= 4'd0;
            found_end <= 4'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    found_flag <= 1'b0;
                    scan_idx <= 4'd0;
                    cycle_count <= 5'd0;
                    
                    if (start) begin
                        state <= SCANNING;
                    end
                end
                
                SCANNING: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check current position if we have enough room for "ly" (needs i and i+1)
                    if (scan_idx < len && scan_idx < 4'd15) begin
                        // Check for "ly" pattern
                        // Current byte should be 'l' (0x6C), next byte should be 'y' (0x79)
                        // Previous byte (if exists) should be alphabetic
                        if (char_at[scan_idx] == 8'h6C && char_at[scan_idx + 4'd1] == 8'h79) begin
                            // Check previous character is alphabetic (or is at position 0)
                            if (scan_idx == 4'd0 || is_alpha(char_at[scan_idx - 4'd1])) begin
                                found_flag <= 1'b1;
                                found_start <= scan_idx - 4'd1;  // Start of "ly" is previous char
                                found_end <= scan_idx + 4'd1;    // End of "ly" is second char
                            end
                        end
                        
                        // Move to next position if not found yet
                        if (!found_flag && scan_idx < len - 4'd2) begin
                            scan_idx <= scan_idx + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end else begin
                        state <= DONE_STATE;
                    end
                    
                    // Force transition if max cycles reached
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    if (found_flag) begin
                        valid <= 1'b1;
                        start_pos <= found_start;
                        end_pos <= found_end;
                    end else begin
                        valid <= 1'b0;
                        start_pos <= 4'd0;
                        end_pos <= 4'd0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule