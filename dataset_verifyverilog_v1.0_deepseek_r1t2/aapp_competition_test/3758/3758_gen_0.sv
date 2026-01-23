module packman_time (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] field,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] BINARY_SEARCH_INIT = 3'd2;
    localparam [2:0] BINARY_SEARCH_LOOP = 3'd3;
    localparam [2:0] CHECK = 3'd4;
    localparam [2:0] BINARY_SEARCH_UPDATE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    // Registers
    reg [2:0] state;
    
    // Parse state
    reg [3:0] parse_index;
    reg [3:0] star_count;
    reg [3:0] packmen_count;
    reg [3:0] stars [0:15];
    reg [3:0] packmen [0:15];
    
    // Binary search
    reg [5:0] low;
    reg [5:0] high;
    reg [5:0] mid;
    reg [5:0] current_T;
    
    // DP registers
    reg [3:0] dp_i, dp_j, dp_l;
    reg dp [0:16][0:16];
    
    // Intermediate calculations
    reg [5:0] option1, option2;
    reg condition;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            parse_index <= 4'd0;
            star_count <= 4'd0;
            packmen_count <= 4'd0;
            low <= 6'd0;
            high <= 6'd0;
            mid <= 6'd0;
            current_T <= 6'd0;
            dp_i <= 4'd0;
            dp_j <= 4'd0;
            dp_l <= 4'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                stars[i] <= 4'd0;
                packmen[i] <= 4'd0;
            end
            
            // Initialize DP array
            for (i = 0; i <= 16; i = i + 1) begin
                for (j = 0; j <= 16; j = j + 1) begin
                    dp[i][j] <= 1'b0;
                end
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        parse_index <= 4'd0;
                        star_count <= 4'd0;
                        packmen_count <= 4'd0;
                    end
                end
                
                PARSE: begin
                    if (parse_index < 4'd16) begin
                        case (field[parse_index*8 +: 8])
                            8'h2A: begin  // '*'
                                stars[star_count] <= parse_index;
                                star_count <= star_count + 4'd1;
                            end
                            8'h50: begin  // 'P'
                                packmen[packmen_count] <= parse_index;
                                packmen_count <= packmen_count + 4'd1;
                            end
                        endcase
                        parse_index <= parse_index + 4'd1;
                    end else begin
                        state <= BINARY_SEARCH_INIT;
                    end
                end
                
                BINARY_SEARCH_INIT: begin
                    low <= 6'd0;
                    high <= 6'd32;
                    state <= BINARY_SEARCH_LOOP;
                end
                
                BINARY_SEARCH_LOOP: begin
                    if (low + 6'd1 < high) begin
                        mid <= (low + high) >> 1;
                        current_T <= (low + high) >> 1;
                        state <= CHECK;
                        
                        // Initialize DP to 0 and dp[0][0] = 1
                        dp_i <= 4'd0;
                        dp_j <= 4'd0;
                        dp_l <= 4'd0;
                        for (i = 0; i <= 16; i = i + 1) begin
                            for (j = 0; j <= 16; j = j + 1) begin
                                dp[i][j] <= 1'b0;
                            end
                        end
                        dp[0][0] <= 1'b1;
                    end else begin
                        result <= high;
                        state <= DONE_STATE;
                    end
                end
                
                CHECK: begin
                    if (dp_i > packmen_count) begin
                        state <= BINARY_SEARCH_UPDATE;
                    end else begin
                        if (dp_i == 4'd0) begin
                            dp_i <= 4'd1;
                        end else if (dp_j <= star_count) begin
                            if (dp_l < dp_j) begin
                                if (dp[dp_i-4'd1][dp_l]) begin
                                    // Compute option1 and option2
                                    if (dp_j == 4'd0) begin
                                        dp[dp_i][dp_j] <= 1'b1;
                                    end else begin
                                        option1 = 6'd2*(packmen[dp_i-4'd1] - stars[dp_l])
                                                 + (stars[dp_j-4'd1] - packmen[dp_i-4'd1]);
                                        option2 = 6'd2*(stars[dp_j-4'd1] - packmen[dp_i-4'd1])
                                                 + (packmen[dp_i-4'd1] - stars[dp_l]);
                                        condition = ((option1 <= current_T) && (option1 <= option2))
                                                 || ((option2 <= current_T) && (option2 <= option1));
                                        if (condition) begin
                                            dp[dp_i][dp_j] <= 1'b1;
                                        end
                                    end
                                end
                                dp_l <= dp_l + 4'd1;
                            end else begin
                                dp_l <= 4'd0;
                                dp_j <= dp_j + 4'd1;
                            end
                        end else begin
                            dp_j <= 4'd0;
                            dp_l <= 4'd0;
                            dp_i <= dp_i + 4'd1;
                        end
                    end
                end
                
                BINARY_SEARCH_UPDATE: begin
                    if (dp[packmen_count][star_count]) begin
                        high <= mid;
                    end else begin
                        low <= mid;
                    end
                    state <= BINARY_SEARCH_LOOP;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule