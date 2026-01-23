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

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] current_max;
    reg [2:0] index;
    reg processing;
    reg [7:0] temp_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_length <= 8'd0;
            done <= 1'b0;
            current_max <= 8'd0;
            index <= 3'd0;
            processing <= 1'b0;
            temp_max <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    processing <= 1'b0;
                    if (start && word_count > 0) begin
                        // Initialize with first word
                        current_max <= str_len_0;
                        max_length <= str_len_0;
                        processing <= 1'b1;
                        index <= 3'd1;
                    end
                end
                
                COMPARE: begin
                    if (processing && index < word_count) begin
                        case (index)
                            3'd1: begin
                                if (str_len_1 > current_max) begin
                                    temp_max <= str_len_1;
                                end else begin
                                    temp_max <= current_max;
                                end
                            end
                            3'd2: begin
                                if (str_len_2 > current_max) begin
                                    temp_max <= str_len_2;
                                end else begin
                                    temp_max <= current_max;
                                end
                            end
                            default: temp_max <= current_max;
                        endcase
                        index <= index + 3'd1;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    processing <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Update max_length when temp_max changes
            if (state == COMPARE && processing) begin
                if (index < word_count && (index == 3'd1 || index == 3'd2)) begin
                    max_length <= temp_max;
                    current_max <= temp_max;
                end
            end
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start && word_count > 0) begin
                    next_state = (word_count > 1) ? COMPARE : COMPLETE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPARE: begin
                if (processing && index < word_count) begin
                    next_state = COMPARE;
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule