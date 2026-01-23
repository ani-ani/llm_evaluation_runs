module dessert_finder (
    input clk,
    input rst_n,
    input start,
    input [8:0] P,
    output reg valid,
    output reg [8:0] B_out,
    output reg [8:0] M_out,
    output reg done,
    output reg [6:0] count
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [8:0] current_B;
    reg [8:0] stored_P;
    
    // Storage for valid pairs (max 64)
    reg [8:0] B_mem [0:63];
    reg [8:0] M_mem [0:63];
    reg [5:0] write_ptr;
    reg [5:0] read_ptr;
    
    // Digit extraction variables
    reg [3:0] p_digits [0:2];
    reg [3:0] b_digits [0:2];
    reg [3:0] m_digits [0:2];
    reg [3:0] p_count;
    reg [3:0] b_count;
    reg [3:0] m_count;
    
    // Validity check flags
    reg all_distinct;
    reg [3:0] used_digits [0:9];
    integer i, j;
    
    // Counter for delay/simulation of 1000 cycles requirement
    reg [9:0] cycle_counter;
    reg processing_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            B_out <= 9'b0;
            M_out <= 9'b0;
            done <= 1'b0;
            count <= 7'b0;
            current_B <= 9'b1;
            write_ptr <= 6'b0;
            read_ptr <= 6'b0;
            cycle_counter <= 10'b0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_B <= 9'd1;
                        write_ptr <= 6'b0;
                        cycle_counter <= 10'b0;
                        processing_done <= 1'b0;
                        stored_P <= P;
                    end
                end

                COMPUTE: begin
                    // Iterate through B values
                    // Check validity and store if valid
                    if (cycle_counter < 10'd1000) begin
                        cycle_counter <= cycle_counter + 1'b1;
                    end

                    if (current_B < stored_P && write_ptr < 6'd64) begin
                        // Check conditions:
                        // 1. B < M (i.e., B < P/2)
                        // 2. All digits distinct
                        
                        // Implicit check: if B >= (stored_P >> 1), skip
                        // Use *2 for comparison to avoid division
                        if ({current_B, 1'b0} < stored_P) begin
                            // Perform digit extraction and distinctness check
                            // Extract digits for P (only once if P changes, but we assume static P during operation)
                            // For simplicity, we re-extract B and M digits each cycle
                            
                            // Extract B digits
                            b_count <= 0;
                            // Extract M digits
                            m_count <= 0;
                            // Initialize used digits array to 0
                            for (i = 0; i < 10; i = i + 1) begin
                                used_digits[i] <= 0;
                            end
                            
                            // We need combinational logic for digit extraction and checking
                            // since this state logic is sequential, we will use a helper logic block below
                            // Here we just trigger the check and store if valid
                            
                            if (all_distinct) begin
                                B_mem[write_ptr] <= current_B;
                                M_mem[write_ptr] <= stored_P - current_B;
                                write_ptr <= write_ptr + 1'b1;
                            end
                        end
                        
                        current_B <= current_B + 1'b1;
                    end else begin
                        // Finished iterating
                        if (cycle_counter >= 10'd1000 || current_B >= stored_P || write_ptr >= 6'd64) begin
                            processing_done <= 1'b1;
                            count <= {1'b0, write_ptr}; // Update count
                            state <= OUTPUT;
                            read_ptr <= 6'b0;
                        end
                    end
                end

                OUTPUT: begin
                    if (read_ptr < write_ptr) begin
                        valid <= 1'b1;
                        B_out <= B_mem[read_ptr];
                        M_out <= M_mem[read_ptr];
                        read_ptr <= read_ptr + 1'b1;
                    end else begin
                        valid <= 1'b0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for digit extraction and distinctness check
    // This logic runs continuously to update 'all_distinct' based on current_B and stored_P
    always @(*) begin
        integer k;
        reg [3:0] digit;
        reg [3:0] p_d [0:2];
        reg [3:0] b_d [0:2];
        reg [3:0] m_d [0:2];
        reg [3:0] p_c, b_c, m_c;
        reg [3:0] u_d [0:9];
        reg temp_distinct;
        
        // Reset arrays
        p_c = 0;
        b_c = 0;
        m_c = 0;
        for (k = 0; k < 10; k = k + 1) begin
            u_d[k] = 0;
        end
        
        // Extract P digits (stored_P)
        // We handle up to 3 digits (max 511 -> 5+1+1=7, but P is 9-bit 0-511)
        if (stored_P > 0) begin
            if (stored_P >= 100) begin
                p_d[2] = stored_P / 100;
                p_d[1] = (stored_P % 100) / 10;
                p_d[0] = stored_P % 10;
                p_c = 3;
                if (p_d[2] == 0) p_c = 2; // Remove leading zero if any
                if (p_d[1] == 0 && p_c == 2) p_c = 1;
            end else if (stored_P >= 10) begin
                p_d[1] = stored_P / 10;
                p_d[0] = stored_P % 10;
                p_c = 2;
                if (p_d[1] == 0) p_c = 1;
            end else begin
                p_d[0] = stored_P;
                p_c = 1;
            end
        end else begin
            p_c = 1;
            p_d[0] = 0;
        end
        
        // Extract B digits (current_B)
        if (current_B >= 100) begin
            b_d[2] = current_B / 100;
            b_d[1] = (current_B % 100) / 10;
            b_d[0] = current_B % 10;
            b_c = 3;
            if (b_d[2] == 0) b_c = 2;
            if (b_d[1] == 0 && b_c == 2) b_c = 1;
        end else if (current_B >= 10) begin
            b_d[1] = current_B / 10;
            b_d[0] = current_B % 10;
            b_c = 2;
            if (b_d[1] == 0) b_c = 1;
        end else begin
            b_d[0] = current_B;
            b_c = 1;
        end
        
        // Extract M digits (P - B)
        // M = stored_P - current_B
        // We compute this value temporarily for extraction
        // Note: current_B < stored_P ensures positive M
        reg [8:0] M_val;
        M_val = stored_P - current_B;
        
        if (M_val >= 100) begin
            m_d[2] = M_val / 100;
            m_d[1] = (M_val % 100) / 10;
            m_d[0] = M_val % 10;
            m_c = 3;
            if (m_d[2] == 0) m_c = 2;
            if (m_d[1] == 0 && m_c == 2) m_c = 1;
        end else if (M_val >= 10) begin
            m_d[1] = M_val / 10;
            m_d[0] = M_val % 10;
            m_c = 2;
            if (m_d[1] == 0) m_c = 1;
        end else begin
            m_d[0] = M_val;
            m_c = 1;
        end
        
        // Check distinctness
        temp_distinct = 1'b1;
        
        // Process P digits
        for (k = 0; k < 3; k = k + 1) begin
            if (k < p_c) begin
                if (u_d[p_d[k]] != 0) temp_distinct = 1'b0;
                else u_d[p_d[k]] = 1;
            end
        end
        
        // Process B digits
        for (k = 0; k < 3; k = k + 1) begin
            if (k < b_c) begin
                if (u_d[b_d[k]] != 0) temp_distinct = 1'b0;
                else u_d[b_d[k]] = 1;
            end
        end
        
        // Process M digits
        for (k = 0; k < 3; k = k + 1) begin
            if (k < m_c) begin
                if (u_d[m_d[k]] != 0) temp_distinct = 1'b0;
                else u_d[m_d[k]] = 1;
            end
        end
        
        all_distinct = temp_distinct;
    end

endmodule
