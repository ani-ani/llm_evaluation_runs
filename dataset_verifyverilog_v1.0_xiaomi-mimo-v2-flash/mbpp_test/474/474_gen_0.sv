module character_replacer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_in [0:7],
    input wire [7:0] old_char,
    input wire [7:0] new_char,
    output reg [7:0] str_out [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;  // 3-bit counter for 0-7
    reg [7:0] str_buf [0:7];  // Internal buffer for captured input
    
    // Counter limit (8 characters = 0-7)
    localparam [2:0] MAX_INDEX = 3'd7;

    // Control signals
    reg processing_done;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            counter <= 3'd0;
            done <= 1'b0;
            processing_done <= 1'b0;
            // Initialize output array
            str_out[0] <= 8'd0;
            str_out[1] <= 8'd0;
            str_out[2] <= 8'd0;
            str_out[3] <= 8'd0;
            str_out[4] <= 8'd0;
            str_out[5] <= 8'd0;
            str_out[6] <= 8'd0;
            str_out[7] <= 8'd0;
            // Initialize buffer
            str_buf[0] <= 8'd0;
            str_buf[1] <= 8'd0;
            str_buf[2] <= 8'd0;
            str_buf[3] <= 8'd0;
            str_buf[4] <= 8'd0;
            str_buf[5] <= 8'd0;
            str_buf[6] <= 8'd0;
            str_buf[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    processing_done <= 1'b0;
                    counter <= 3'd0;
                    
                    if (start) begin
                        // Capture input string into buffer
                        str_buf[0] <= str_in[0];
                        str_buf[1] <= str_in[1];
                        str_buf[2] <= str_in[2];
                        str_buf[3] <= str_in[3];
                        str_buf[4] <= str_in[4];
                        str_buf[5] <= str_in[5];
                        str_buf[6] <= str_in[6];
                        str_buf[7] <= str_in[7];
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    // Process current character
                    if (str_buf[counter] == old_char) begin
                        str_out[counter] <= new_char;
                    end else begin
                        str_out[counter] <= str_buf[counter];
                    end
                    
                    // Increment counter
                    counter <= counter + 3'd1;
                    
                    // Check if done processing all 8 characters
                    if (counter == MAX_INDEX) begin
                        processing_done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule