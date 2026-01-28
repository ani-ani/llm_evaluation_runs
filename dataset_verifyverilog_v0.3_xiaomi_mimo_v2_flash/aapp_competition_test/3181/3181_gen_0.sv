module monotone_seq_generator(
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [7:0] K,
    output reg [7:0] data,
    output reg [7:0] index,
    output reg valid,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] OUTPUT  = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] ERROR   = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Control registers
    reg [7:0] N_reg;
    reg [7:0] K_reg;
    reg [7:0] min_K;
    reg [7:0] q;
    reg [7:0] r;
    
    // Output generation registers
    reg [7:0] current_block;
    reg [7:0] block_size;
    reg [7:0] start_num;
    reg [7:0] block_counter;
    reg [7:0] output_counter;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Compute ceil(sqrt(N)) for N<=16
    function automatic [7:0] ceil_sqrt(input [7:0] n);
        begin
            case (n)
                8'd0, 8'd1: ceil_sqrt = 8'd1;
                8'd2, 8'd3: ceil_sqrt = 8'd2;
                8'd4, 8'd5, 8'd6, 8'd7: ceil_sqrt = 8'd3;
                8'd8, 8'd9, 8'd10, 8'd11, 8'd12, 8'd13, 8'd14, 8'd15: ceil_sqrt = 8'd4;
                8'd16: ceil_sqrt = 8'd4;
                default: ceil_sqrt = 8'd16;
            endcase
        end
    endfunction
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            INIT: begin
                if ((K_reg < min_K) || (K_reg > N_reg)) begin
                    next_state = ERROR;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (output_counter >= N_reg) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            DONE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = DONE;
                end
            end
            
            ERROR: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = ERROR;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            data <= 8'd0;
            index <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            N_reg <= 8'd0;
            K_reg <= 8'd0;
            min_K <= 8'd0;
            q <= 8'd0;
            r <= 8'd0;
            current_block <= 8'd0;
            block_size <= 8'd0;
            start_num <= 8'd0;
            block_counter <= 8'd0;
            output_counter <= 8'd0;
            cycle_counter <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    error <= 1'b0;
                    cycle_counter <= 8'd0;
                    output_counter <= 8'd0;
                end
                
                INIT: begin
                    // Latch inputs
                    N_reg <= N;
                    K_reg <= K;
                    
                    // Compute min_K = ceil(sqrt(N))
                    min_K <= ceil_sqrt(N);
                    
                    // Compute q and r
                    // Since K<=16, we can compute division by repeated subtraction
                    q <= 8'd0;
                    r <= N;
                    
                    // Reset counters
                    current_block <= 8'd0;
                    block_counter <= 8'd0;
                    output_counter <= 8'd0;
                    block_size <= 8'd0;
                    start_num <= 8'd0;
                    
                    // Compute q and r in parallel (will be ready by OUTPUT state)
                    // Using combinational logic:
                    q <= (K != 8'd0) ? (N / K) : 8'd0;
                    r <= (K != 8'd0) ? (N % K) : N;
                    
                    done <= 1'b0;
                    valid <= 1'b0;
                    error <= 1'b0;
                end
                
                OUTPUT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (cycle_counter == 8'd0) begin
                        // First cycle: initialize first block
                        current_block <= 8'd0;
                        
                        // Compute block size for block 0
                        if (K_reg > 8'd0 && 8'd0 < r) begin
                            block_size <= q + 8'd1;
                        end else begin
                            block_size <= q;
                        end
                        
                        // Compute start_num for block 0
                        start_num <= 8'd1;  // i=0, so 1 + 0*q + min(0,r) = 1
                        
                        // Initialize output
                        data <= 8'd0;
                        index <= 8'd0;
                        valid <= 1'b0;
                        output_counter <= 8'd0;
                        block_counter <= 8'd0;
                    end else if (cycle_counter <= N_reg) begin
                        // Generate output element
                        
                        // Check if we need to move to next block
                        if (block_counter >= block_size) begin
                            // Move to next block
                            current_block <= current_block + 8'd1;
                            block_counter <= 8'd0;
                            
                            // Compute next block size
                            if ((current_block + 8'd1) < K_reg && (current_block + 8'd1) < r) begin
                                block_size <= q + 8'd1;
                            end else begin
                                block_size <= q;
                            end
                            
                            // Compute next start_num
                            start_num <= 8'd1 + (current_block + 8'd1) * q + 
                                        ((current_block + 8'd1) < r ? (current_block + 8'd1) : r);
                            
                            // Output from new block (first element is start_num + block_size - 1)
                            data <= start_num + (q + (current_block < r ? 8'd1 : 8'd0)) - 8'd1;
                            index <= output_counter;
                            valid <= 1'b1;
                            block_counter <= 8'd1;
                        end else begin
                            // Continue within current block (decreasing)
                            block_counter <= block_counter + 8'd1;
                            data <= start_num + block_size - 8'd1 - block_counter;
                            index <= output_counter;
                            valid <= 1'b1;
                        end
                        
                        output_counter <= output_counter + 8'd1;
                    end else begin
                        valid <= 1'b0;
                    end
                    
                    // Safety check for infinite loops
                    if (cycle_counter >= MAX_CYCLES) begin
                        error <= 1'b1;
                        state <= ERROR;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    data <= 8'd0;
                    index <= 8'd0;
                end
                
                ERROR: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    valid <= 1'b0;
                    data <= 8'd0;
                    index <= 8'd0;
                end
            endcase
        end
    end

endmodule