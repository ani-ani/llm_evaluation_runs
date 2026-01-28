module decimal_to_binary_str(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] decimal_in,
    output reg done,
    output reg valid,
    output reg [7:0] binary_str [0:15]
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] START_CONVERSION = 4'd1;
    localparam [3:0] DIVIDE_LOOP = 4'd2;
    localparam [3:0] CONVERT_BITS = 4'd3;
    localparam [3:0] BUILD_STRING = 4'd4;
    localparam [3:0] COMPLETE = 4'd5;

    reg [3:0] state, next_state;
    reg [7:0] temp_value;
    reg [7:0] bit_array [0:7];
    reg [3:0] bit_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            temp_value <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            bit_counter <= 4'd0;
            cycle_count <= 8'd0;
            // Initialize bit_array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                bit_array[i] <= 8'd0;
            end
            // Initialize binary_str
            for (i = 0; i < 16; i = i + 1) begin
                binary_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= START_CONVERSION;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                START_CONVERSION: begin
                    cycle_count <= cycle_count + 8'd1;
                    temp_value <= decimal_in;
                    bit_counter <= 4'd0;
                    next_state <= DIVIDE_LOOP;
                end

                DIVIDE_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Extract bits using division by 2
                    bit_array[bit_counter] <= temp_value[0];
                    temp_value <= temp_value >> 1;
                    bit_counter <= bit_counter + 4'd1;
                    if (bit_counter == 4'd8) begin
                        next_state <= CONVERT_BITS;
                    end else begin
                        next_state <= DIVIDE_LOOP;
                    end
                end

                CONVERT_BITS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Build the binary string
                    // Positions 0-1: 'd', 'b'
                    binary_str[0] <= 8'd100; // 'd'
                    binary_str[1] <= 8'd98;  // 'b'
                    // Positions 2-9: bits (MSB to LSB)
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (bit_array[7 - i] == 1'b1) begin
                            binary_str[2 + i] <= 8'd49; // '1'
                        end else begin
                            binary_str[2 + i] <= 8'd48; // '0'
                        end
                    end
                    // Positions 10-11: 'd', 'b'
                    binary_str[10] <= 8'd100; // 'd'
                    binary_str[11] <= 8'd98;  // 'b'
                    // Positions 12-15: spaces
                    for (i = 12; i < 16; i = i + 1) begin
                        binary_str[i] <= 8'd32; // space
                    end
                    next_state <= BUILD_STRING;
                end

                BUILD_STRING: begin
                    cycle_count <= cycle_count + 8'd1;
                    next_state <= COMPLETE;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule