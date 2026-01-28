module move_zeroes_to_end (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] arr_len,
    output reg [7:0] result [0:15],
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] input_buffer [0:15];  // Internal buffer for input
    reg [3:0] scan_index;            // Current index being scanned
    reg [3:0] write_index;           // Position to write non-zero
    reg [7:0] zero_count;            // Number of zeros to append
    reg [7:0] cycle_count;           // Timeout counter
    integer i;                       // Loop variable

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all signals
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            scan_index <= 4'd0;
            write_index <= 4'd0;
            zero_count <= 8'd0;
            cycle_count <= 8'd0;
            // Clear result array
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                input_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    scan_index <= 4'd0;
                    write_index <= 4'd0;
                    zero_count <= 8'd0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        busy <= 1'b1;
                        // Copy input to buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < arr_len) begin
                                input_buffer[i] <= arr[i];
                            end else begin
                                input_buffer[i] <= 8'd0;
                            end
                        end
                        // Initialize result buffer
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process current element
                    if (scan_index < arr_len) begin
                        if (input_buffer[scan_index] != 8'd0) begin
                            // Non-zero: write to next available position
                            result[write_index] <= input_buffer[scan_index];
                            write_index <= write_index + 4'd1;
                        end else begin
                            // Zero: increment counter
                            zero_count <= zero_count + 8'd1;
                        end
                        scan_index <= scan_index + 4'd1;
                    end else begin
                        // All elements scanned
                        // Append zeros
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < zero_count) begin
                                result[write_index + i] <= 8'd0;
                            end
                        end
                        state <= COMPLETE;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= 8'd200) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule