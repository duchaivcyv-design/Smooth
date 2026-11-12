#ifndef TitaniumKernelOverdrive_h
#define TitaniumKernelOverdrive_h

#import <Foundation/Foundation.h>
#import <mach/mach.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ====================================================================================================
// [TARGET-90] HẰNG SỐ CÔNG KHAI — thread priority ceiling info
// ====================================================================================================

/** Importance mục tiêu — request lên kernel (kernel clamp ở 63 cho userland) */
extern const int32_t TITANIUM_TARGET_IMPORTANCE;

/** Max importance mà kernel cho phép userland thread (hard-coded XNU MAXPRI_USER) */
extern const int32_t TITANIUM_KERNEL_USERLAND_MAX;

/** Max importance cho task (khác thread importance) */
extern const int32_t TITANIUM_TASK_IMPORTANCE_MAX;

// ====================================================================================================
// MEMORY PATCHING
// ====================================================================================================

/**
 * @brief Ghi đè bộ nhớ executable page của process hiện tại.
 *
 * Multi-strategy: JIT toggle → vm_protect RWX → vm_protect RWX|COPY → mprotect → vm_remap COW.
 * Verify bằng memcmp sau mỗi strategy, rollback về original nếu fail, thử strategy kế tiếp.
 * Clear icache sau khi success.
 *
 * Lưu ý: hàm này patch memory trong process hiện tại. Để patch kernel memory thật
 * cần dùng kwritebuf_phys từ libjailbreak — không nằm trong scope hàm này.
 *
 * @param targetAddr Địa chỉ bộ nhớ cần ghi đè.
 * @param patchBytes Con trỏ tới mảng byte chứa dữ liệu patch.
 * @param size Kích thước dữ liệu cần ghi (bytes).
 * @return true nếu ghi + verify thành công, false nếu mọi strategy fail.
 */
bool Titanium_ForceKernelMemoryWrite(void *targetAddr, const void *patchBytes, size_t size);

// ====================================================================================================
// THREAD OVERCLOCK — normal priority path (importance clamp 63)
// ====================================================================================================

/**
 * @brief Nâng priority + realtime class cho TOÀN BỘ thread trong process.
 *
 * Mỗi thread:
 *   - THREAD_PRECEDENCE_POLICY: importance=90 (kernel clamp xuống 63)
 *   - THREAD_THROTTLE_POLICY: pset_limit=0 (throttle off)
 *   - THREAD_AFFINITY_POLICY: tag=1 (P-core)
 *   - THREAD_TIME_CONSTRAINT_POLICY: period=1ms, computation=0.9ms, constraint=1ms,
 *     preemptible=FALSE (hard realtime — lối thoát khỏi 63 clamp)
 *   - QoS: USER_INTERACTIVE
 *   - nice: -10 (userland max)
 *
 * Cũng áp dụng task_qos_policy LATENCY_QOS_TIER_0 + THROUGHPUT_QOS_TIER_0
 * cho task cha, wire stack current thread, set I/O disk policy IMPORTANT.
 */
void Titanium_OverclockChipAndUnthrottle(void);

// ====================================================================================================
// [TARGET-90] KERNEL-WRITE BYPASS — patch thread struct importance = 90 thật
// ====================================================================================================

/**
 * @brief Ghi importance=90 vào thread struct kernel field, bypass 63 clamp.
 *
 * YÊU CẦU: kwritebuf_phys từ Dopamine libjailbreak (verified 0x104dbb00c).
 * RỦI RO: offset field sai → kernel panic ngay. Placeholder 0x68 cần RE cho
 * đúng iOS version (iOS 15: 0x60, iOS 16.5-16.7: 0x68, iOS 17: khác).
 *
 * @param threadPortAddr Địa chỉ kernel của thread struct (không phải mach_port_t name).
 * @param targetImportance Giá trị importance muốn ghi (thường 90).
 * @return YES nếu kwritebuf_phys return 0, NO nếu lib không có hoặc write fail.
 */
bool Titanium_KernelWriteThreadImportance(uint64_t threadPortAddr, int32_t targetImportance);

/**
 * @brief Enumerate toàn bộ thread của process, gọi Titanium_KernelWriteThreadImportance.
 *
 * CẦN FILL: threadStructAddr lookup (convert mach_port_t → kernel struct address)
 * thông qua task->threads list hoặc zmq port table. Hàm này skip threads không resolve được.
 *
 * Gọi SAU Titanium_OverclockChipAndUnthrottle để có baseline userland max trước.
 */
void Titanium_KernelWriteAllThreadImportance(void);

// ====================================================================================================
// JETSAM — memory limit bypass
// ====================================================================================================

/**
 * @brief Bypass jetsam memory limits cho process hiện tại.
 *
 * Memorystatus commands:
 *   - SET_JETSAM_HIGH_WATER_MARK: 0x7FFFFFFF (~2GB, kernel max int32)
 *   - SET_JETSAM_TASK_LIMIT: 0x7FFFFFFF
 *   - SET_PRIORITY_PROPERTIES: JETSAM_PRIORITY_CRITICAL (19)
 *   - SET_PROCESS_IS_FREEZABLE: 0 (không bị suspend)
 *   - SET_PROCESS_IS_MANAGED: 0 (không theo jetsam policy)
 *   - rlimit RLIMIT_AS + RLIMIT_DATA: infinity
 */
void Titanium_BreakJetsamMemoryLimits(void);

// ====================================================================================================
// UTILITY
// ====================================================================================================

/**
 * @brief Wire vùng bộ nhớ vào RAM (mlock equivalent), không bị swap.
 *
 * @param addr Địa chỉ cần wire.
 * @param size Kích thước.
 */
void Titanium_WireAllMemory(void *addr, size_t size);

/**
 * @brief Convenience — gọi Titanium_OverclockChipAndUnthrottle + Titanium_BreakJetsamMemoryLimits.
 *
 * KHÔNG tự gọi Titanium_KernelWriteAllThreadImportance (cần FILL offset trước).
 * Nếu muốn full target-90 với kernel write, gọi tay 3 hàm theo thứ tự:
 *   1. Titanium_OverclockChipAndUnthrottle()
 *   2. Titanium_KernelWriteAllThreadImportance()   // FILL offset
 *   3. Titanium_BreakJetsamMemoryLimits()
 */
void Titanium_ApplyAllOverdrive(void);

#ifdef __cplusplus
}
#endif

#endif /* TitaniumKernelOverdrive_h */
