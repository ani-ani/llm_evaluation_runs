module char_creator #(
    parameter K = 5,
    parameter N = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [K-1:0] str0,
    input wire [K-1:0] str1,
    input wire [K-1:0] str2,
    input wire [K-1:0] str3,
    input wire [K-1:0] str4,
    input wire [K-1:0] str5,
    input wire [K-1:0] str6,
    input wire [K-1:0] str7,
    input wire [3:0] n,
    output reg [K-1:0] result,
    output reg done
);
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] LOOP_INNER = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [2:0] j_reg;
    reg [K-1:0] candidate_reg;
    reg [K-1:0] best_candidate;
    reg [4:0] max_min;
    reg [4:0] current_min;
    reg [3:0] n_reg;
    reg [K-1:0] str_reg [0:7];
    
    localparam [K-1:0] MAX_CANDIDATE = {K{1'b1}};
    
    function automatic [4:0] popcount(input [K-1:0] data);
        integer i;
        begin
            popcount = 5'd0;
            for (i = 0; i < K; i = i + 1) begin
                popcount = popcount + data[i];
            end
        end
    endfunction
    
    integer i; // For-loop variable for array initialization
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= {K{1'b0}};
            j_reg <= 3'd0;
            candidate_reg <= {K{1'b0}};
            best_candidate <= {K{1'b0}};
            max_min <= 5'd0;
            current_min <= 5'd0;
            n_reg <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                str_reg[i] <= {K{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin // Capture input when start
                        str_reg[0] <= str0;
                        str_reg[1] <= str1;
                        str_reg[2] <= str2;
                        str_reg[3] <= str3;
                        str_reg[4] <= str4;
                        str_reg[5] <= str5;
                        str_reg[6] <= str6;
                        str_reg[7] <= str7;
                        n_reg <= n;
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    candidate_reg <= {K{1'b0}};
                    best_candidate <= {K{1'b0}};
                    max_min <= 5'd0;
                    current_min <= 5'd31; // Wider than max K=20
                    j_reg <= 3'd0;
                    state <= LOOP_INNER;
                end
                
                LOOP_INNER: begin
                    if (j_reg < n_reg) begin
                        // Compute Hamming distance
                        if (popcount(candidate_reg ^ str_reg[j_reg]) < current_min) begin
                            current_min <= popcount(candidate_reg ^ str_reg[j_reg]);
                        end
                        j_reg <= j_reg + 3'd1;
                    end else begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    if (current_min > max_min) begin
                        max_min <= current_min;
                        best_candidate <= candidate_reg;
                    end else if (current_min == max_min && candidate_reg < best_candidate) begin
                        best_candidate <= candidate_reg;
                    end
                    
                    if (candidate_reg == MAX_CANDIDATE) begin
                        state <= DONE_STATE;
                    end else begin
                        candidate_reg <= candidate_reg + {{(K-1){1'b0}}, 1'b1};
                        current_min <= 5'd31;
                        j_reg <= 3'd0;
                        state <= LOOP_INNER;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= best_candidate;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule