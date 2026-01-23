module BaseDigitGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] denominations [0:7],
    input wire [4:0] k,
    output reg [4:0] count,
    output reg [4:0] remainders [0:31],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] GCD       = 3'd1;
    localparam [2:0] GENERATE  = 3'd2;
    localparam [2:0] SORT      = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // GCD computation registers
    reg [15:0] gcd_a, gcd_b;
    reg [15:0] gcd_temp;
    reg [2:0] gcd_idx;
    
    // Generate state registers
    reg [4:0] gen_i;
    reg [4:0] current_remainder;
    reg [4:0] temp_remainder;
    
    // Sorting registers
    reg [4:0] sort_i, sort_j;
    reg [4:0] swap_temp;
    reg sorted;
    
    // Temporary array for sorting
    reg [4:0] temp_array [0:31];
    
    // Computation variables
    reg [4:0] g;  // gcd result
    reg [4:0] k_reg;  // copy of k
    
    integer i;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            gcd_idx <= 3'd0;
            gen_i <= 5'd0;
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sorted <= 1'b0;
            g <= 5'd0;
            k_reg <= 5'd0;
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            current_remainder <= 5'd0;
            temp_remainder <= 5'd0;
            for (i = 0; i < 32; i = i + 1) begin
                remainders[i] <= 5'd0;
                temp_array[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    gcd_idx <= 3'd0;
                    gen_i <= 5'd0;
                    sort_i <= 5'd0;
                    sort_j <= 5'd0;
                    sorted <= 1'b0;
                    g <= 5'd0;
                    k_reg <= 5'd0;
                    count <= 5'd0;
                    current_remainder <= 5'd0;
                    temp_remainder <= 5'd0;
                    if (start) begin
                        // Initialize GCD with first denomination and k
                        if (n > 0) begin
                            gcd_a <= denominations[0][4:0];
                        end else begin
                            gcd_a <= k;
                        end
                        gcd_b <= k;
                        k_reg <= k;
                    end
                end
                
                GCD: begin
                    // Compute GCD using denominations
                    if (gcd_idx < n && gcd_idx < 3'd8) begin
                        gcd_temp <= gcd_a % gcd_b;
                        if (gcd_temp == 0) begin
                            gcd_a <= gcd_b;
                        end else begin
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_temp;
                        end
                    end else if (gcd_idx == 3'd0 && n == 0) begin
                        // No denominations, gcd = k
                        g <= k[4:0];
                    end
                end
                
                GENERATE: begin
                    // Generate remainders: (i * g) % k
                    temp_remainder <= (gen_i * g) % k_reg;
                end
                
                SORT: begin
                    // Bubble sort (simple for small arrays)
                    if (sort_j > sort_i) begin
                        if (temp_array[sort_j] < temp_array[sort_j-5'd1]) begin
                            swap_temp <= temp_array[sort_j-5'd1];
                            temp_array[sort_j-5'd1] <= temp_array[sort_j];
                            temp_array[sort_j] <= swap_temp;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    count <= k_reg / g;
                    // Copy temp_array to output
                    for (i = 0; i < 32; i = i + 1) begin
                        remainders[i] <= temp_array[i];
                    end
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = GCD;
            end
            
            GCD: begin
                if (gcd_idx < n && gcd_idx < 3'd8) begin
                    gcd_idx = gcd_idx + 3'd1;
                    if (gcd_temp == 0)
                        next_state = GCD;
                    else
                        next_state = GCD;
                end else begin
                    // GCD calculation complete
                    if (n == 0)
                        g = k[4:0];
                    else
                        g = gcd_a[4:0];
                    gcd_idx = 3'd0;
                    next_state = GENERATE;
                end
            end
            
            GENERATE: begin
                // Store computed remainder
                temp_array[gen_i] = temp_remainder;
                gen_i = gen_i + 5'd1;
                
                if (gen_i < (k_reg / g)) begin
                    next_state = GENERATE;
                end else begin
                    gen_i = 5'd0;
                    next_state = SORT;
                end
            end
            
            SORT: begin
                // Bubble sort implementation
                if (!sorted) begin
                    if (sort_i < (k_reg / g) - 5'd1) begin
                        if (sort_j < (k_reg / g) - 5'd1 - sort_i) begin
                            sort_j = sort_j + 5'd1;
                        end else begin
                            sort_j = 5'd0;
                            sort_i = sort_i + 5'd1;
                        end
                    end else begin
                        sorted = 1'b1;
                    end
                end
                
                if (sorted || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE)
            next_state = FINISH;
    end

endmodule