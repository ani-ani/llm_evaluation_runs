module string_rearrange #(
    parameter N = 8,
    parameter LOG2_N = 3,
    parameter ALPHABET = 26
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] char_in [0:N-1],
    output reg [4:0] char_out [0:N-1],
    output reg out_valid,
    output reg done,
    output reg impossible
);
    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COUNT_FREQ = 3'd1;
    localparam [2:0] FIND_MAX   = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] GEN_OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;
    
    reg [2:0] current_state, next_state;
    reg [LOG2_N-1:0] freq [0:ALPHABET-1];
    reg [LOG2_N-1:0] max_freq;
    reg [7:0] threshold;
    reg [7:0] count;
    reg [4:0] current_letter;
    reg [LOG2_N-1:0] output_count;
    reg [7:0] idx;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            impossible <= 1'b0;
            for (i = 0; i < N; i = i + 1) char_out[i] <= 5'd0;
            for (i = 0; i < ALPHABET; i = i + 1) freq[i] <= {LOG2_N{1'b0}};
            max_freq <= {LOG2_N{1'b0}};
            threshold <= (N + 1) >> 1;
            count <= 8'd0;
            idx <= 8'd0;
            current_letter <= 5'd0;
            output_count <= {LOG2_N{1'b0}};
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        out_valid <= 1'b0;
                        impossible <= 1'b0;
                    end
                end
                
                COUNT_FREQ: begin
                    if (count < N) begin
                        freq[char_in[count]] <= freq[char_in[count]] + 1;
                        count <= count + 8'd1;
                    end
                end
                
                FIND_MAX: begin
                    if (count < ALPHABET) begin
                        if (freq[count] > max_freq) begin
                            max_freq <= freq[count];
                        end
                        count <= count + 8'd1;
                    end
                end
                
                CHECK: begin
                    if (max_freq > threshold) begin
                        impossible <= 1'b1;
                    end
                end
                
                GEN_OUTPUT: begin
                    if (idx < N) begin
                        if (output_count < freq[current_letter]) begin
                            char_out[idx] <= current_letter;
                            idx <= idx + 8'd1;
                            output_count <= output_count + 1;
                            // Prevent adjacent same char
                            if (idx > 0 && char_out[idx-1] == current_letter) begin
                                char_out[idx] <= current_letter + 5'd1;
                            end
                        end else begin
                            current_letter <= current_letter + 5'd1;
                            output_count <= {LOG2_N{1'b0}};
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    out_valid <= ~impossible;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE:       if (start) next_state = COUNT_FREQ;
            COUNT_FREQ: if (count == N) begin
                            count <= 8'd0;
                            next_state = FIND_MAX;
                        end
            FIND_MAX:   if (count == ALPHABET) next_state = CHECK;
            CHECK:      next_state = (max_freq > threshold) ? DONE_STATE : GEN_OUTPUT;
            GEN_OUTPUT: if (idx == N) next_state = DONE_STATE;
            DONE_STATE: next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end
endmodule