module longest_word_length(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_len_0,
    input wire [7:0] str_len_1,
    input wire [7:0] str_len_2,
    input wire [2:0] word_count,
    output reg [7:0] max_length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] current_max;
    reg [2:0] index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 8'd0;
            done <= 1'b0;
            current_max <= 8'd0;
            index <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && word_count > 0) begin
                        // Initialize with first word
                        current_max <= str_len_0;
                        max_length <= str_len_0;
                        index <= 3'd1;
                        if (word_count > 1)
                            state <= COMPARE;
                        else
                            state <= COMPLETE;
                    end
                end
                
                COMPARE: begin
                    // Compare current index with max
                    if (index < word_count) begin
                        case (index)
                            3'd1: begin
                                if (str_len_1 > current_max) begin
                                    current_max <= str_len_1;
                                    max_length <= str_len_1;
                                end
                            end
                            3'd2: begin
                                if (str_len_2 > current_max) begin
                                    current_max <= str_len_2;
                                    max_length <= str_len_2;
                                end
                            end
                        endcase
                        index <= index + 1'd1;
                        if (index >= word_count - 1'd1)
                            state <= COMPLETE;
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule