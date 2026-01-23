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
    reg [3:0] depth;    // Nesting depth
    
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOADING = 2'd1;
    localparam [1:0] SCANNING = 2'd2;
    localparam [1:0] DONE = 2'd3;
    reg [1:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 4'd0;
            scan_idx <= 4'd0;
            depth <= 4'd0;
            result_char <= 8'd0;
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
                        depth <= 4'd0;
                    end
                end
                
                LOADING: begin
                    if (load) begin
                        if (load_idx < 4'd16) begin
                            buffer[load_idx] <= char_in;
                            load_idx <= load_idx + 4'd1;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
                
                SCANNING: begin
                    if (scan_idx < load_idx) begin
                        // Process character
                        case (buffer[scan_idx])
                            8'd40: begin // '('
                                depth <= depth + 4'd1;
                                if (depth == 4'd1) begin // First '(' of a group
                                    result_char <= buffer[scan_idx];
                                    result_valid <= 1'b1;
                                end else begin
                                    result_valid <= 1'b0;
                                end
                            end
                            8'd41: begin // ')'
                                if (depth > 4'd0) begin
                                    depth <= depth - 4'd1;
                                    result_char <= buffer[scan_idx];
                                    result_valid <= 1'b1;
                                end else begin
                                    result_valid <= 1'b0;
                                end
                            end
                            8'd32: begin // Space
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
                    done <= 1'b0; // Pulse done for one cycle
                    if (!start) begin
                        state <= IDLE;
                        load_idx <= 4'd0; // Reset buffer index for next string
                    end
                end
            endcase
        end
    end
endmodule