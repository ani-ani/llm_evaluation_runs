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
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] COUNT_FREQ = 3'b001;
    localparam [2:0] FIND_MAX = 3'b010;
    localparam [2:0] CHECK = 3'b011;
    localparam [2:0] GEN_OUTPUT = 3'b100;
    localparam [2:0] DONE = 3'b101;

    // Internal registers
    reg [LOG2_N-1:0] freq [0:ALPHABET-1];
    reg [LOG2_N-1:0] max_freq;
    reg [4:0] threshold;
    reg [5:0] count;
    reg [5:0] idx;
    reg [4:0] current_letter;
    reg [LOG2_N-1:0] output_count;
    reg [2:0] current_state, next_state;
    reg [5:0] temp_count;

    integer i;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            out_valid <= 0;
            impossible <= 0;
            for (i = 0; i < N; i = i + 1) char_out[i] <= 5'd0;
            for (i = 0; i < ALPHABET; i = i + 1) freq[i] <= 3'd0;
            max_freq <= 3'd0;
            threshold <= 5'd4;
            count <= 6'd0;
            idx <= 6'd0;
            current_letter <= 5'd0;
            output_count <= 3'd0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < ALPHABET; i = i + 1) freq[i] <= 3'd0;
                        count <= 6'd0;
                        done <= 0;
                        out_valid <= 0;
                        impossible <= 0;
                    end
                end
                
                COUNT_FREQ: begin
                    if (count < N) begin
                        freq[char_in[count]] <= freq[char_in[count]] + 3'd1;
                        count <= count + 6'd1;
                    end
                end
                
                FIND_MAX: begin
                    if (count < ALPHABET) begin
                        if (freq[count] > max_freq) begin
                            max_freq <= freq[count];
                        end
                        count <= count + 6'd1;
                    end else begin
                        count <= 6'd0;
                    end
                end
                
                CHECK: begin
                    if (max_freq > threshold) begin
                        impossible <= 1;
                    end else begin
                        impossible <= 0;
                        current_letter <= 5'd0;
                        output_count <= 3'd0;
                        idx <= 6'd0;
                    end
                end
                
                GEN_OUTPUT: begin
                    if (idx < N) begin
                        if (output_count < freq[current_letter]) begin
                            char_out[idx] <= current_letter;
                            idx <= idx + 6'd1;
                            output_count <= output_count + 3'd1;
                        end else begin
                            current_letter <= current_letter + 5'd1;
                            output_count <= 3'd0;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1;
                    out_valid <= 1;
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
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
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule