module negabase_converter (
    input clk,
    input rst_n,
    input start,
    input [63:0] p,
    input [15:0] k,
    output reg [5:0] count,
    output reg [15:0] coeff_out,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam OUTPUT = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [63:0] current_p, next_current_p;
    reg [5:0] write_ptr, next_write_ptr;
    reg [5:0] read_ptr, next_read_ptr;
    reg [5:0] stored_count, next_stored_count;
    
    // Buffer for coefficients (64 slots of 16 bits)
    reg [15:0] coeff_buffer [0:63];
    
    // Intermediate arithmetic signals
    wire signed [63:0] signed_p;
    wire signed [15:0] signed_k;
    wire signed [63:0] div_result;
    wire signed [63:0] mod_result;
    wire signed [63:0] neg_div_result;
    wire signed [63:0] adjusted_mod;
    wire signed [63:0] next_p_temp;
    
    assign signed_p = $signed(current_p);
    assign signed_k = $signed(k);
    
    // Division and Modulo Logic
    // We need to handle the mathematical definition:
    // r = p % k, but if r < 0, r += k, p += k
    // then p = -(p / k)
    
    always @(*) begin
        // Default assignments for next state values
        next_state = state;
        next_current_p = current_p;
        next_write_ptr = write_ptr;
        next_read_ptr = read_ptr;
        next_stored_count = stored_count;
        coeff_out = 16'b0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_current_p = p;
                    next_write_ptr = 6'b0;
                    next_stored_count = 6'b0;
                end
            end
            
            PROCESSING: begin
                if (current_p == 64'b0) begin
                    // Done processing, move to output
                    next_state = OUTPUT;
                    next_read_ptr = 6'b0;
                end else begin
                    // Perform one iteration
                    // 1. Calculate r = p % k
                    // Verilog % operator for signed numbers returns remainder with sign of dividend.
                    // We need to check if result is negative.
                    
                    reg signed [63:0] temp_r;
                    reg signed [63:0] temp_p;
                    reg signed [63:0] div_res;
                    
                    temp_r = signed_p % signed_k;
                    
                    // Adjust if negative
                    if (temp_r < 0) begin
                        temp_r = temp_r + signed_k;
                        temp_p = signed_p + signed_k;
                    end else begin
                        temp_p = signed_p;
                    end
                    
                    // Calculate p = -(p / k)
                    // Integer division truncates towards zero in Verilog for signed.
                    div_res = temp_p / signed_k;
                    next_current_p = -div_res;
                    
                    // Store coefficient
                    // coeff_buffer[write_ptr] = temp_r;
                    // We handle array write in sequential logic or via a direct assignment if supported.
                    // Since we are in combinational block, we can't directly drive array.
                    // We will handle the buffer write in the sequential block logic or use an intermediate.
                    // Actually, let's use a control signal for the sequential block to write.
                    // But to keep combinational logic clean, we will just update pointers.
                    // We will perform the write in the sequential always block logic based on flags.
                    
                    // To support this in combinational logic correctly for next state:
                    // We need to signal that a write should happen.
                    // However, standard Verilog sequential logic is easier.
                    // Let's assume the buffer write happens in the sequential block triggered by state.
                    // We need to pass the calculated value to the sequential block.
                    // Let's use a temporary register for the value to be written.
                end
            end
            
            OUTPUT: begin
                if (read_ptr < stored_count) begin
                    coeff_out = coeff_buffer[read_ptr];
                    next_read_ptr = read_ptr + 1;
                end else begin
                    next_state = DONE;
                    done = 1'b1;
                end
            end
            
            DONE: begin
                // Hold state
                done = 1'b1;
            end
        endcase
    end
    
    // Sequential Logic and State Update
    // We need a separate combinational block for arithmetic to handle the math cleanly
    // because array writes in combinational logic are tricky for synthesis if driven by continuous assignments.
    // Let's refine the PROCESSING state logic to be explicit.
    
    reg signed [63:0] calc_r;
    reg signed [63:0] calc_p;
    reg do_write;
    reg [15:0] val_to_write;
    
    always @(*) begin
        calc_r = signed_p % signed_k;
        calc_p = signed_p;
        do_write = 1'b0;
        val_to_write = 16'b0;
        
        if (state == PROCESSING && current_p != 0) begin
            if (calc_r < 0) begin
                calc_r = calc_r + signed_k;
                calc_p = calc_p + signed_k;
            end
            val_to_write = calc_r[15:0]; // Truncate to 16 bits (k <= 2000, so fits)
            do_write = 1'b1;
            // Note: next_current_p update logic is in the main FSM block or here.
            // Let's move the next_current_p logic here to avoid duplication.
            next_current_p = -(calc_p / signed_k);
        end
    end

    // The main FSM block needs to handle the pointer updates and state transitions
    // We will rewrite the FSM block to be purely state/next-state and standard logic
    // to ensure synthesis correctness.
    
    // Re-declaring the FSM block cleanly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_p <= 64'b0;
            write_ptr <= 6'b0;
            read_ptr <= 6'b0;
            stored_count <= 6'b0;
            count <= 6'b0;
            coeff_out <= 16'b0;
            done <= 1'b0;
        end else begin
            // Default assignments
            coeff_out <= 16'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        current_p <= p;
                        write_ptr <= 6'b0;
                        stored_count <= 6'b0;
                    end
                end
                
                PROCESSING: begin
                    if (current_p == 64'b0) begin
                        state <= OUTPUT;
                        read_ptr <= 6'b0;
                        count <= 6'b0; // Reset output counter
                    end else begin
                        // Perform calculation
                        // Using the values calculated in combinational logic above
                        // Note: comb logic triggers based on current_p and state
                        
                        // We need to re-evaluate the math here if we rely on comb logic outputs
                        // or implement it directly.
                        
                        // Let's implement directly to ensure correct timing
                        // Math is: r = p % k. If r < 0: r += k, p += k. p = -(p/k).
                        
                        // Verilog arithmetic for signed
                        // reg signed [63:0] temp_p = $signed(current_p);
                        // reg signed [63:0] temp_k = $signed(k);
                        // reg signed [63:0] temp_r;
                        
                        // We must use blocking assignments for intermediate vars in always block
                        begin
                            reg signed [63:0] temp_p;
                            reg signed [63:0] temp_k;
                            reg signed [63:0] temp_r;
                            
                            temp_p = $signed(current_p);
                            temp_k = $signed(k);
                            temp_r = temp_p % temp_k;
                            
                            if (temp_r < 0) begin
                                temp_r = temp_r + temp_k;
                                temp_p = temp_p + temp_k;
                            end
                            
                            // Update buffer
                            if (write_ptr < 64) begin
                                coeff_buffer[write_ptr] <= temp_r[15:0];
                                write_ptr <= write_ptr + 1;
                                stored_count <= stored_count + 1;
                            end
                            
                            // Update p
                            // p = -(p / k)
                            // Since temp_p might have been adjusted
                            temp_p = temp_p / temp_k;
                            current_p <= -temp_p;
                        end
                    end
                end
                
                OUTPUT: begin
                    if (read_ptr < stored_count) begin
                        coeff_out <= coeff_buffer[read_ptr];
                        read_ptr <= read_ptr + 1;
                        count <= count + 1;
                    end else begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                
                DONE: begin
                    // Wait for reset or new start (handled in IDLE transition, but 'start' in DONE?
                    // Usually 'start' is ignored in DONE until reset, or we transition to IDLE.
                    // The problem says "wait for start" in IDLE. So we stay in DONE until reset.
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

module TopModule();
    // This is just to ensure the module is valid Verilog if run as a whole.
    // The main module is negabase_converter.
endmodule