module text_match_wordz(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_array [0:15],  // 16-character input buffer
    input wire [4:0] str_len,             // Actual string length (1-16)
    output reg result,
    output reg done
);

// Sequential state machine
// States: IDLE, SCANNING, COMPLETE
reg [1:0] state;
reg [4:0] index;
reg found_z;

localparam IDLE = 2'b00;
localparam SCANNING = 2'b01;
localparam COMPLETE = 2'b10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        index <= 5'b0;
        found_z <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= SCANNING;
                    index <= 5'b0;
                    found_z <= 1'b0;
                end
            end
            
            SCANNING: begin
                if (index < str_len) begin
                    // Check if current character is 'z' (0x7A)
                    if (char_array[index] == 8'h7A) begin
                        found_z <= 1'b1;
                    end
                    index <= index + 1'b1;
                end else begin
                    state <= COMPLETE;
                    result <= found_z;
                    done <= 1'b1;
                end
            end
            
            COMPLETE: begin
                done <= 1'b0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule