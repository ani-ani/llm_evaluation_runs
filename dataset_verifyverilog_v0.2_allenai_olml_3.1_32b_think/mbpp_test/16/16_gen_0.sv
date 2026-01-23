module text_lowercase_underscore (input clk,input rst_n,input start,input [7:0] char_in,input [3:0] char_index,input valid,output reg result,output reg done);
reg [1:0] state;
localparam IDLE = 2'b00;
localparam READING = 2'b01;
localparam COMPLETE = 2'b10;
reg [1:0] state_reg = IDLE;

reg [4:0] char_count =0; // counts valid characters received
reg [4:0] cycle_count =0; // counts cycles in READING state up to 16

reg [15:0] underscore_count =0;
reg [15:0] letters_before =0;
reg [15:0] letters_after =0;
reg before_underscore =1'b1;
reg after_underscore =1'b0;
reg all_chars_valid =1;
reg valid_string =1;

output reg result;
output reg done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        char_count <=0;
        cycle_count <=0;
        underscore_count <=0;
        letters_before <=0;
        letters_after <=0;
        before_underscore <=1'b1;
        after_underscore <=1'b0;
        all_chars_valid <=1'b1;
        valid_string <=1'b0;
        result <=0;
        done <=0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= READING;
                    char_count <=0;
                    cycle_count <=0;
                    underscore_count <=0;
                    letters_before <=0;
                    letters_after <=0;
                    before_underscore <=1'b1;
                    after_underscore <=1'b0;
                    all_chars_valid <=1'b1;
                    valid_string <=1'b0;
                end
            end
            READING: begin
                if (cycle_count <16) begin
                    cycle_count <= cycle_count +1;
                end
                if (valid) begin
                    if ( (char_in >= 'a' && char_in <= 'z') || (char_in == '_') ) begin
                        if (char_in == '_') begin
                            underscore_count <= underscore_count +1;
                            if (underscore_count >1) begin
                                all_chars_valid <=1'b0;
                            end
                            if (char_index ==0 || char_index ==15) begin
                                all_chars_valid <=1'b0;
                            end
                            before_underscore <=1'b0;
                            after_underscore <=1'b1;
                        end else begin
                            if (before_underscore) begin
                                letters_before <= letters_before +1;
                            end else begin
                                letters_after <= letters_after +1;
                            end
                        end
                        char_count <= char_count +1;
                    end else begin
                        all_chars_valid <=1'b0;
                        char_count <= char_count +1;
                    end
                end else begin
                    all_chars_valid <=1'b0;
                end
                if (cycle_count ==16) begin
                    valid_string <= (underscore_count ==1) && (letters_before >=1) && (letters_after >=1) && (all_chars_valid) && (char_count ==16);
                    state_reg <= COMPLETE;
                end
            end
            COMPLETE: begin
                done <=1'b1;
                result <= valid_string;
            end
        endcase
    end
end
endmodule