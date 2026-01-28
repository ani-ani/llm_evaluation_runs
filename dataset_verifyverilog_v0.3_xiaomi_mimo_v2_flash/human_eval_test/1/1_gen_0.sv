module separate_paren_groups (
    input wire clk,
    input wire rst_n,
    input wire load,
    input wire [7:0] char_in,
    input wire start,
    output reg [7:0] result_char,
    output reg result_valid,
    output reg done
);
    // Internal buffer for 16 characters
    reg [7:0] buffer [0:15];
    reg [3:0] load_idx; // 0-15
    reg [3:0] scan_idx; // 0-15
    reg signed [4:0] depth;    // Nesting depth, signed to handle decrement safely
    
    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] LOADING = 2'b01;
    localparam [1:0] SCANNING = 2'b10;
    localparam [1:0] DONE = 2'b11;
    reg [1:0] state;
    
    // ASCII constants
    localparam [7:0] ASCII_OPEN = 8'h28;
    localparam [7:0] ASCII_CLOSE = 8'h29;
    localparam [7:0] ASCII_SPACE = 8'h20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 4'd0;
            scan_idx <= 4'd0;
            depth <= 5'sd0;
            result_char <= 8'h00;
            result_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (load) begin
                        state <= LOADING;
                        buffer[load_idx] <= char_in;
                        load_idx <= load_idx + 4'd1;
                    end else if (start && load_idx > 4'd0) begin
                        state <= SCANNING;
                        scan_idx <= 4'd0;
                        depth <= 5'sd0;
                    end
                end
                
                LOADING: begin
                    if (load) begin
                        if (load_idx < 4'd15) begin
                            buffer[load_idx] <= char_in;
                            load_idx <= load_idx + 4'd1;
                        end else begin
                            // Buffer full, overwrite last position or stay? 
                            // Staying at 15 prevents index overflow.
                            buffer[load_idx] <= char_in;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                
                SCANNING: begin
                    if (scan_idx < load_idx) begin
                        // Process character
                        case (buffer[scan_idx])
                            ASCII_OPEN: begin // '('
                                depth <= depth + 5'sd1;
                                if (depth == 5'sd0) begin // First '(' of a group
                                    result_char <= buffer[scan_idx];
                                    result_valid <= 1'b1;
                                end else begin
                                    result_valid <= 1'b0;
                                end
                            end
                            ASCII_CLOSE: begin // ')'
                                if (depth > 5'sd0) begin
                                    depth <= depth - 5'sd1;
                                    result_char <= buffer[scan_idx];
                                    result_valid <= 1'b1;
                                end else begin
                                    // Unmatched closing paren, ignore
                                    result_valid <= 1'b0;
                                end
                            end
                            ASCII_SPACE: begin // Space
                                result_valid <= 1'b0;
                            end
                            default: begin
                                result_valid <= 1'b0;
                            end
                        endcase
                        scan_idx <= scan_idx + 4'd1;
                    end else begin
                        // Finished scanning
                        state <= DONE;
                        result_valid <= 1'b0;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    done <= 1'b0; // Clear done pulse
                    if (!start) begin
                        state <= IDLE;
                        load_idx <= 4'd0; // Reset buffer index for next string
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule