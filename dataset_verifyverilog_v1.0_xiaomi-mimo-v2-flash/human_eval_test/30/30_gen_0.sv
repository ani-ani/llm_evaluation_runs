module filter_positives (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in[0:15],
    input wire [3:0] len_in,
    output reg [7:0] result[0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] idx;          // Current input index being processed
    reg [3:0] out_idx;      // Current output index to write
    reg [3:0] len_buf;      // Buffer for len_in
    reg [7:0] arr_buf[0:15]; // Buffer for input array
    reg [3:0] out_count;    // Counter for positive numbers found

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            len_out <= 4'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
            len_buf <= 4'd0;
            out_count <= 4'd0;
            // Initialize result array
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
            // Initialize buffer array
            for (i = 0; i < 16; i = i + 1) begin
                arr_buf[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs into buffers
                        len_buf <= len_in;
                        for (i = 0; i < 16; i = i + 1) begin
                            arr_buf[i] <= arr_in[i];
                        end
                        // Initialize counters
                        idx <= 4'd0;
                        out_idx <= 4'd0;
                        out_count <= 4'd0;
                        // Clear result array (optional, but ensures defined values)
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                        
                        // Handle edge case: len_in = 0
                        if (len_in == 4'd0) begin
                            state <= DONE;
                        end else begin
                            state <= PROCESSING;
                        end
                    end
                end

                PROCESSING: begin
                    // Check if current element is positive
                    // Sign bit is arr_buf[idx][7], 0 means positive (including 0)
                    // But 0 is not positive, so we need value > 0
                    // arr_buf[idx] > 0 means positive value
                    if (arr_buf[idx][7] == 1'b0 && arr_buf[idx] != 8'd0) begin
                        // Positive number found
                        result[out_idx] <= arr_buf[idx];
                        out_idx <= out_idx + 4'd1;
                        out_count <= out_count + 4'd1;
                    end
                    
                    // Move to next input element
                    idx <= idx + 4'd1;
                    
                    // Check if processing is complete
                    if (idx == (len_buf - 4'd1)) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    len_out <= out_count;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule