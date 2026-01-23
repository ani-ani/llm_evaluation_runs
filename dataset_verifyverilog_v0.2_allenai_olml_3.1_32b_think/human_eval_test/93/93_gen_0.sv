module message_encoder (
    input clk,
    input rst_n, // active low
    input start,
    input [127:0] message_in,
    input [7:0] valid_length, // unused
    output reg [127:0] message_out,
    output reg done
);
// Transformation function
function automatic [7:0] transform_char;
    input [7:0] c;
    begin
        if (c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z') begin
            // Swap case
            c = c ^ 0x20;
            // Now apply vowel replacement
            if (c == 'A') c = 'C';
            else if (c == 'E') c = 'G';
            else if (c == 'I') c = 'K';
            else if (c == 'O') c = 'Q';
            else if (c == 'U') c = 'Y';
            else if (c == 'a') c = 'c';
            else if (c == 'e') c = 'g';
            else if (c == 'i') c = 'k';
            else if (c == 'o') c = 'q';
            else if (c == 'u') c = 'y';
        end
    end
endfunction
// State registers
reg [1:0] state;
reg [3:0] counter;
reg [127:0] transformed_msg;
reg [127:0] message_out; // or assign message_out = transformed_msg;

// Assign output
assign message_out = transformed_msg;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00; // IDLE
        counter <= 4'd0;
        transformed_msg <= 128'd0;
        done <= 1'b0;
    end else begin
        if (state == 2'b00) begin // IDLE
            if (start) begin
                state <= 2'b01; // PROCESSING
                transformed_msg <= message_in;
                counter <= 4'd0;
            end
        end else if (state == 2'b01) begin // PROCESSING
            if (counter < 4'd16) begin
                // Process current character
                [7:0] char;
                int i;
                i = counter;
                // Get character from message_in
                char = message_in[(i*8 +7): i*8];
                char = transform_char(char);
                // Update transformed_msg's i-th byte
                reg [7:0] current_byte;
                current_byte = transformed_msg[i*8 +7 : i*8];
                reg [7:0] diff;
                diff = current_byte ^ char;
                reg [127:0] byte_mask;
                byte_mask = ( (1<<8)-1 ) << (i*8);
                transformed_msg <= transformed_msg ^ (diff & byte_mask);
                counter <= counter +1;
            end else begin
                state <= 2'b10; // DONE
                done <= 1'b1;
            end
        end else if (state == 2'b10) begin // DONE
            // Stay in DONE
            if (start) begin
                // If start is asserted again, maybe restart? But spec doesn't say.
                // Assume no, stay in DONE
            end
        end
    end
end
endmodule