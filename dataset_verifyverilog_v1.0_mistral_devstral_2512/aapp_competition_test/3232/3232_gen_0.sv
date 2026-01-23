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

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_FREQ = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] GEN_OUTPUT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [LOG2_N-1:0] freq [0:ALPHABET-1];
    reg [LOG2_N-1:0] max_freq;
    reg [4:0] threshold;
    reg [5:0] count;
    reg [5:0] idx;
    reg [4:0] current_letter;
    reg [LOG2_N-1:0] output_count;
    reg [2:0] state, next_state;

    integer i;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            impossible <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                char_out[i] <= 5'd0;
            end
            for (i = 0; i < ALPHABET; i = i + 1) begin
                freq[i] <= 3'd0;
            end
            max_freq <= 3'd0;
            threshold <= 5'd13; // N >> 1 = 4, but using 5 bits
            count <= 6'd0;
            idx <= 6'd0;
            current_letter <= 5'd0;
            output_count <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < ALPHABET; i = i + 1) begin
                            freq[i] <= 3'd0;
                        end
                        count <= 6'd0;
                        done <= 1'b0;
                        out_valid <= 1'b0;
                        impossible <= 1'b0;
                    end
                end
                
                COUNT_FREQ: begin
                    if (count < N) begin
                        freq[char_in[count]] <= freq[char_in[count]] + 1'b1;
                        count <= count + 1'b1;
                    end
                end
                
                FIND_MAX: begin
                    if (count < ALPHABET) begin
                        if (freq[count] > max_freq) begin
                            max_freq <= freq[count];
                        end
                        count <= count + 1'b1;
                    end else begin
                        count <= 6'd0;
                    end
                end
                
                CHECK: begin
                    if (max_freq > threshold) begin
                        impossible <= 1'b1;
                    end else begin
                        impossible <= 1'b0;
                        current_letter <= 5'd0;
                        output_count <= 3'd0;
                        idx <= 6'd0;
                    end
                end
                
                GEN_OUTPUT: begin
                    if (idx < N) begin
                        if (output_count < freq[current_letter]) begin
                            char_out[idx] <= current_letter;
                            idx <= idx + 1'b1;
                            output_count <= output_count + 1'b1;
                        end else begin
                            current_letter <= current_letter + 1'b1;
                            output_count <= 3'd0;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    out_valid <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = COUNT_FREQ;
            end
            
            COUNT_FREQ: begin
                if (count == N) next_state = FIND_MAX;
            end
            
            FIND_MAX: begin
                if (count == ALPHABET) next_state = CHECK;
            end
            
            CHECK: begin
                if (max_freq > threshold) begin
                    next_state = DONE;
                end else begin
                    next_state = GEN_OUTPUT;
                end
            end
            
            GEN_OUTPUT: begin
                if (idx == N) next_state = DONE;
            end
            
            DONE: begin
                next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule