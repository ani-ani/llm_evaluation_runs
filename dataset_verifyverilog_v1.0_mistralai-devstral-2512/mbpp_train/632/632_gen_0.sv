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
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SCAN     = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [3:0] read_ptr;
    reg [3:0] write_ptr;
    reg [3:0] zero_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal buffer for input array
    reg [7:0] input_buffer [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_ptr <= 4'd0;
            write_ptr <= 4'd0;
            zero_count <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            
            // Initialize result array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
            end
            
            // Initialize input buffer
            for (i = 0; i < 16; i = i + 1) begin
                input_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start && !busy) begin
                        // Copy input to buffer
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            input_buffer[i] <= arr[i];
                        end
                        
                        state <= SCAN;
                        read_ptr <= 4'd0;
                        write_ptr <= 4'd0;
                        zero_count <= 4'd0;
                        busy <= 1'b1;
                    end
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (read_ptr < arr_len) begin
                        if (input_buffer[read_ptr] != 8'd0) begin
                            // Non-zero element
                            result[write_ptr] <= input_buffer[read_ptr];
                            write_ptr <= write_ptr + 4'd1;
                        end else begin
                            // Zero element
                            zero_count <= zero_count + 4'd1;
                        end
                        
                        read_ptr <= read_ptr + 4'd1;
                    end else begin
                        // Fill remaining positions with zeros
                        integer i;
                        for (i = 0; i < zero_count; i = i + 1) begin
                            if (write_ptr + i < 16) begin
                                result[write_ptr + i] <= 8'd0;
                            end
                        end
                        
                        // Clear unused positions
                        for (i = arr_len; i < 16; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                        
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule