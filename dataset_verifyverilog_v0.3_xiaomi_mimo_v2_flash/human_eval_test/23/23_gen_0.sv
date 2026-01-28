module strlen (
    input clk,
    input rst_n,
    input start,
    input [7:0] string [0:15],
    output reg [4:0] length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COUNTING  = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] position;          // 0-15 index
    reg [4:0] count;             // 0-16 length
    reg [7:0] current_byte;
    reg [4:0] cycle_count;       // 5 bits for up to 32 cycles
    localparam [4:0] MAX_CYCLES = 5'd20;

    // Wire for byte access (to avoid array slicing in always block)
    wire [7:0] byte_at_position;
    assign byte_at_position = string[position];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            length <= 5'd0;
            done <= 1'b0;
            position <= 4'd0;
            count <= 5'd0;
            current_byte <= 8'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    position <= 4'd0;
                    count <= 5'd0;
                    
                    if (start) begin
                        current_byte <= byte_at_position;
                        state <= COUNTING;
                    end
                end

                COUNTING: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check if current byte is null terminator
                    if (current_byte == 8'd0) begin
                        length <= count;
                        state <= DONE;
                    end else begin
                        // Increment position and counter
                        position <= position + 4'd1;
                        count <= count + 5'd1;
                        
                        // Check for timeout (max 20 cycles) or end of array
                        if ((cycle_count >= MAX_CYCLES) || (position == 4'd15)) begin
                            // Force done if we've exceeded cycle limit or array bounds
                            // This handles malformed strings without null terminator
                            length <= count + 5'd1;
                            state <= DONE;
                        end else begin
                            // Read next byte
                            current_byte <= byte_at_position;
                        end
                    end
                end

                DONE: begin
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