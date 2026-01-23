module pikeman_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] t0,
    input [63:0] T,
    output reg [31:0] count,
    output reg [31:0] penalty,
    output reg done
);
    
    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        GENERATE,
        SORT,
        CALCULATE,
        DONE
    } state_t;
    
    state_t current_state, next_state;
    
    // Internal registers
    reg [31:0] mem [0:15];
    reg [31:0] lfsr_reg;
    reg [31:0] lfsr_next;
    reg [5:0] generate_counter;
    reg [5:0] calculate_index;
    reg [63:0] accumulated_time;
    reg [32:0] penalty_temp;
    reg sort_start;
    
    // Constants
    localparam LFSR_POLY = 16'h8005;
    localparam MODULUS = 32'd1000000007;
    
    // LFSR logic
    always_comb begin
        lfsr_next = {lfsr_reg[14:0], lfsr_reg[31], lfsr_reg[30], lfsr_reg[29], lfsr_reg[28]} ^ 
                    (lfsr_reg[31] ? LFSR_POLY[15:0] : 16'h0);
    end
    
    // Bitonic Sorting Network for 16 elements
    // Comparator function
    function automatic void comparator;
        input [31:0] a, b;
        output [31:0] min, max;
        begin
            min = a < b ? a : b;
            max = a < b ? b : a;
        end
    endfunction
    
    // Sorting network stages
    always_comb begin
        if (sort_start) begin
            // Stage 1
            reg [31:0] stage1 [0:15];
            for (int i = 0; i < 8; i++) begin
                comparator(mem[2*i], mem[2*i+1], stage1[2*i], stage1[2*i+1]);
            end
            
            // Stage 2
            reg [31:0] stage2 [0:15];
            for (int i = 0; i < 4; i++) begin
                comparator(stage1[4*i], stage1[4*i+2], stage2[4*i], stage2[4*i+2]);
                comparator(stage1[4*i+1], stage1[4*i+3], stage2[4*i+1], stage2[4*i+3]);
            end
            
            // Stage 3
            reg [31:0] stage3 [0:15];
            for (int i = 0; i < 2; i++) begin
                comparator(stage2[8*i], stage2[8*i+4], stage3[8*i], stage3[8*i+4]);
                comparator(stage2[8*i+1], stage2[8*i+5], stage3[8*i+1], stage3[8*i+5]);
                comparator(stage2[8*i+2], stage2[8*i+6], stage3[8*i+2], stage3[8*i+6]);
                comparator(stage2[8*i+3], stage2[8*i+7], stage3[8*i+3], stage3[8*i+7]);
            end
            
            // Stage 4
            reg [31:0] stage4 [0:15];
            for (int i = 0; i < 1; i++) begin
                comparator(stage3[0], stage3[8], stage4[0], stage4[8]);
                comparator(stage3[1], stage3[9], stage4[1], stage4[9]);
                comparator(stage3[2], stage3[10], stage4[2], stage4[10]);
                comparator(stage3[3], stage3[11], stage4[3], stage4[11]);
                comparator(stage3[4], stage3[12], stage4[4], stage4[12]);
                comparator(stage3[5], stage3[13], stage4[5], stage4[13]);
                comparator(stage3[6], stage3[14], stage4[6], stage4[14]);
                comparator(stage3[7], stage3[15], stage4[7], stage4[15]);
            end
            
            // Stage 5
            for (int i = 0; i < 8; i++) begin
                comparator(stage4[2*i], stage4[2*i+1], mem[2*i], mem[2*i+1]);
            end
        end
    end
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count <= 0;
            penalty <= 0;
            done <= 0;
            generate_counter <= 0;
            calculate_index <= 0;
            accumulated_time <= 0;
            penalty_temp <= 0;
            sort_start <= 0;
            lfsr_reg <= 0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        next_state = GENERATE;
                        mem[0] = t0;
                        lfsr_reg = t0;
                        generate_counter = 1;
                    end
                end
                
                GENERATE: begin
                    if (generate_counter < 16) begin
                        lfsr_reg = lfsr_next;
                        mem[generate_counter] = lfsr_reg;
                        generate_counter = generate_counter + 1;
                    end else begin
                        next_state = SORT;
                        sort_start = 1;
                    end
                end
                
                SORT: begin
                    sort_start = 0;
                    next_state = CALCULATE;
                    accumulated_time = 0;
                    penalty_temp = 0;
                    calculate_index = 0;
                end
                
                CALCULATE: begin
                    if (calculate_index < 16) begin
                        accumulated_time = accumulated_time + mem[calculate_index];
                        if (accumulated_time <= T) begin
                            count = count + 1;
                            penalty_temp = penalty_temp + accumulated_time;
                            if (penalty_temp >= MODULUS) begin
                                penalty_temp = penalty_temp - MODULUS;
                            end
                        end else begin
                            next_state = DONE;
                        end
                        calculate_index = calculate_index + 1;
                    end else begin
                        next_state = DONE;
                    end
                end
                
                DONE: begin
                    penalty = penalty_temp;
                    done = 1;
                    if (!start) begin
                        next_state = IDLE;
                        done = 0;
                    end
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // Default assignments
    always_comb begin
        next_state = current_state;
    end
    
endmodule